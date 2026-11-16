#!/usr/bin/env bash
# Lance les tests lourds sur GitHub Actions quand le PC de Léo est indisponible.
# Usage : bash ci/en-ligne.sh --ref <branche> [--suites "a b"] [--captures] [--mesures] [--phases "comparateur audio"]
# Le workflow a-la-demande.yml doit exister sur main (limite de workflow_dispatch).
# Dispatch refusé (403/404 du proxy) : repli par push d'une branche en-ligne/<horodatage>
# (ci/en-ligne.json), supprimée à la fin.
# Déclenche (REST), attend la fin (sondage toutes les 30 s), télécharge les artefacts dans
# /tmp/en-ligne/<run_id>/ (d'abord par git fetch de la branche resultats-en-ligne/<run_id>, que le
# workflow publie et que ce script supprime ensuite ; repli : artefact) et n'affiche que le résumé et les échecs. Nécessite gh (authentifié).
set -uo pipefail
repo="${CD_EN_LIGNE_REPO:-Xynph/cadrage-debordement}"
wf="a-la-demande.yml"
ref="main"; suites=""; captures=false; mesures=false; phases=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="${2:?--ref attend une branche}"; shift 2 ;;
    --suites) suites="${2-}"; shift 2 ;;
    --captures) captures=true; shift ;;
    --mesures) mesures=true; shift ;;
    --phases) phases="${2-}"; phases="${phases//[\"\\\'\`\$]/}"; shift 2 ;;
    -h|--help) sed -n 2,6p "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done
[[ -n "${suites// /}" || $captures == true || $mesures == true ]] || { echo "Rien à lancer : --suites, --captures ou --mesures." >&2; exit 2; }

debut="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
branche=""
body="$(printf '{"ref":"main","inputs":{"ref":"%s","suites":"%s","captures":"%s","mesures":"%s","phases":"%s"}}' "$ref" "$suites" "$captures" "$mesures" "$phases")"
if echo "$body" | gh api -X POST "repos/$repo/actions/workflows/$wf/dispatches" --input - >/dev/null 2>&1; then
  echo "Lancé (dispatch) : ref=$ref suites='${suites}' captures=$captures mesures=$mesures"
else
  # Secours : push d'une branche en-ligne/<horodatage> = <ref> + ci/en-ligne.json (workflow réagit au push).
  echo "Dispatch refusé : secours par push d'une branche temporaire."
  branche="en-ligne/$(date -u +%Y%m%d-%H%M%S)"
  tmp="$(mktemp -d)"
  git fetch -q origin "$ref" main || { echo "Fetch impossible." >&2; exit 1; }
  git worktree add -q --detach "$tmp/w" "origin/$ref" || exit 1
  (
    cd "$tmp/w" || exit 1
    # Le workflow et ses scripts viennent de main s'ils manquent sur la branche testée.
    git checkout -q origin/main -- .github/workflows/a-la-demande.yml 2>/dev/null || true
    [[ -f ci/en-ligne-run.sh ]] || git checkout -q origin/main -- ci/en-ligne-run.sh 2>/dev/null || true
    printf '{"ref":"%s","suites":"%s","captures":%s,"mesures":%s,"phases":"%s"}\n' "$ref" "$suites" "$captures" "$mesures" "$phases" > ci/en-ligne.json
    git add -f ci/en-ligne.json .github/workflows/a-la-demande.yml ci/en-ligne-run.sh
    git -c user.name=en-ligne -c user.email=en-ligne@users.noreply.github.com commit -q -m "chore: test en ligne temporaire ($ref)" || exit 1
    git push -q origin "HEAD:refs/heads/$branche"
  ) || { echo "Push de secours refusé." >&2; git worktree remove --force "$tmp/w" 2>/dev/null; rm -rf "$tmp"; exit 1; }
  git worktree remove --force "$tmp/w" 2>/dev/null; rm -rf "$tmp"
  echo "Lancé (push $branche) : ref=$ref suites='${suites}' captures=$captures mesures=$mesures"
fi
nettoyer() { [[ -n "$branche" ]] && gh api -X DELETE "repos/$repo/git/refs/heads/$branche" >/dev/null 2>&1 && echo "Branche temporaire $branche supprimée."; }
trap nettoyer EXIT

# Retrouver l'exécution créée après le déclenchement.
run=""
for _ in $(seq 1 12); do
  sleep 5
  if [[ -n "$branche" ]]; then
    run="$(gh api "repos/$repo/actions/workflows/$wf/runs?event=push&branch=$branche&per_page=1" --jq '.workflow_runs[0].id // empty' 2>/dev/null)"
  else
    run="$(gh api "repos/$repo/actions/workflows/$wf/runs?event=workflow_dispatch&created=>=$debut&per_page=5" --jq '.workflow_runs | sort_by(.created_at) | last | .id // empty' 2>/dev/null)"
  fi
  [[ -n "$run" ]] && break
done
[[ -n "$run" ]] || { echo "Exécution introuvable." >&2; exit 1; }
echo "Exécution $run : https://github.com/$repo/actions/runs/$run"

while :; do
  etat="$(gh api "repos/$repo/actions/runs/$run" --jq '.status + " " + (.conclusion // "")' 2>/dev/null || echo "reseau")"
  [[ "$etat" == completed* ]] && break
  sleep 30
done
conclusion="${etat#completed }"

dest="/tmp/en-ligne/$run"; mkdir -p "$dest"
# 1. Branche de résultats (git passe le proxy, pas le téléchargement d'artefacts). Le workflow la publie
#    même en échec ; on laisse quelques secondes à la dernière étape.
rb="resultats-en-ligne/$run"; recupere=false
for _ in 1 2 3 4; do
  if git fetch -q --depth=1 "https://github.com/$repo.git" "refs/heads/$rb" 2>/dev/null; then
    git archive FETCH_HEAD | tar -x -C "$dest" && recupere=true
    break
  fi
  sleep 10
done
if $recupere; then
  echo "Résultats récupérés par git ($rb)."
  if git push -q origin --delete "$rb" 2>/dev/null; then echo "Branche $rb supprimée."
  else echo "Branche $rb NON supprimée (refus du proxy ?) : à nettoyer ; le workflow ne garde que les 5 plus récentes." >&2; fi
else
  # 2. Repli : artefact (souvent 403 depuis le cloud de Claude).
  art="$(gh api "repos/$repo/actions/runs/$run/artifacts" --jq '.artifacts[] | select(.name=="resultats-en-ligne") | .id' | head -1)"
  if [[ -n "$art" ]] && gh api "repos/$repo/actions/artifacts/$art/zip" > "$dest/a.zip" 2>/dev/null; then
    unzip -q -o "$dest/a.zip" -d "$dest" && rm -f "$dest/a.zip"
  else
    echo "Ni branche ni artefact. Détail : gh api repos/$repo/actions/runs/$run/jobs puis .../actions/jobs/<id>/logs (le workflow y écrit résumé, échecs et fin des journaux)." >&2
  fi
fi
echo "Conclusion : $conclusion · artefacts : $dest"
[[ -f "$dest/resume.md" ]] && cat "$dest/resume.md"
[[ -f "$dest/echecs.txt" ]] && { echo "--- Échecs ---"; cat "$dest/echecs.txt"; }
[[ "$conclusion" == success ]]
