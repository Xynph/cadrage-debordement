#!/usr/bin/env bash
# Lance les tests lourds sur GitHub Actions quand le PC de Léo est indisponible.
# Usage : bash ci/en-ligne.sh --ref <branche> [--suites "a b"] [--captures] [--mesures]
# Le workflow a-la-demande.yml doit exister sur main (limite de workflow_dispatch).
# Dispatch refusé (403/404 du proxy) : repli par push d'une branche en-ligne/<horodatage>
# (ci/en-ligne.json), supprimée à la fin.
# Déclenche (REST), attend la fin (sondage toutes les 30 s), télécharge les artefacts dans
# /tmp/en-ligne/<run_id>/ et n'affiche que le résumé et les échecs. Nécessite gh (authentifié).
set -uo pipefail
repo="${CD_EN_LIGNE_REPO:-Xynph/cadrage-debordement}"
wf="a-la-demande.yml"
ref="main"; suites=""; captures=false; mesures=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="${2:?--ref attend une branche}"; shift 2 ;;
    --suites) suites="${2-}"; shift 2 ;;
    --captures) captures=true; shift ;;
    --mesures) mesures=true; shift ;;
    -h|--help) sed -n 2,6p "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done
[[ -n "${suites// /}" || $captures == true || $mesures == true ]] || { echo "Rien à lancer : --suites, --captures ou --mesures." >&2; exit 2; }

debut="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
branche=""
body="$(printf '{"ref":"main","inputs":{"ref":"%s","suites":"%s","captures":"%s","mesures":"%s"}}' "$ref" "$suites" "$captures" "$mesures")"
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
    git checkout -q origin/main -- .github/workflows/a-la-demande.yml ci/en-ligne-run.sh 2>/dev/null || true
    printf '{"ref":"%s","suites":"%s","captures":%s,"mesures":%s}\n' "$ref" "$suites" "$captures" "$mesures" > ci/en-ligne.json
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
art="$(gh api "repos/$repo/actions/runs/$run/artifacts" --jq '.artifacts[] | select(.name=="resultats-en-ligne") | .id' | head -1)"
if [[ -n "$art" ]] && gh api "repos/$repo/actions/artifacts/$art/zip" > "$dest/a.zip" 2>/dev/null; then
  unzip -q -o "$dest/a.zip" -d "$dest" && rm -f "$dest/a.zip"
else
  echo "Aucun artefact (échec avant l'exécution des tests ?). Journal : gh run view $run --repo $repo --log-failed" >&2
fi
echo "Conclusion : $conclusion · artefacts : $dest"
[[ -f "$dest/resume.md" ]] && cat "$dest/resume.md"
[[ -f "$dest/echecs.txt" ]] && { echo "--- Échecs ---"; cat "$dest/echecs.txt"; }
[[ "$conclusion" == success ]]
