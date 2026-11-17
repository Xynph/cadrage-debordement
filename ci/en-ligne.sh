#!/usr/bin/env bash
# Lance les tests lourds sur GitHub Actions quand le PC de Léo est indisponible.
# Usage : bash ci/en-ligne.sh --ref <branche> [--suites "a b"] [--captures [intro,finitions,fiche-club,
#   feuille-espoir,match-rendu,comparateur,audio,reception,creation,derby,avis-staff,meteo,prolongations-staff,investissements]] [--mesures]   (--captures seul = toutes les captures)
#         bash ci/en-ligne.sh --menage   (supprime les branches en-ligne/* et tmp/* de plus d'un jour)
# Le workflow a-la-demande.yml doit exister sur main (limite de workflow_dispatch).
# Dispatch refusé (403/404 du proxy) : repli par push d'une branche en-ligne/<horodatage>
# (ci/en-ligne.json), supprimée à la fin.
# Déclenche (REST), attend la fin (sondage toutes les 30 s), lit les résultats publiés par git dans la
# branche resultats-en-ligne (runs/<run_id>/), les extrait dans /tmp/en-ligne/<run_id>/ et n'affiche que
# le résumé et les échecs (l'artefact du run reste 7 jours pour Léo). Nécessite gh (authentifié).
set -uo pipefail
repo="${CD_EN_LIGNE_REPO:-Xynph/cadrage-debordement}"
wf="a-la-demande.yml"
ref="main"; suites=""; captures=false; quoi=""; mesures=false; menage=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="${2:?--ref attend une branche}"; shift 2 ;;
    --suites) suites="${2-}"; shift 2 ;;
    --captures) captures=true; shift
      if [[ $# -gt 0 && "$1" != --* ]]; then quoi="$1"; shift; fi ;;
    --menage) menage=true; shift ;;
    --mesures) mesures=true; shift ;;
    -h|--help) sed -n 2,6p "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done
[[ "$quoi" =~ ^[a-z,-]*$ ]] || { echo "Liste de captures invalide : $quoi" >&2; exit 2; }
if [[ $menage == true ]]; then
  body='{"ref":"main","inputs":{"menage":"true"}}'
  echo "$body" | gh api -X POST "repos/$repo/actions/workflows/$wf/dispatches" --input - >/dev/null \
    && echo "Ménage lancé : https://github.com/$repo/actions/workflows/$wf" || { echo "Dispatch refusé." >&2; exit 1; }
  exit 0
fi
[[ -n "${suites// /}" || $captures == true || $mesures == true ]] || { echo "Rien à lancer : --suites, --captures ou --mesures." >&2; exit 2; }

debut="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
branche=""
cle="$(date -u +%Y%m%d%H%M%S)-$$-$RANDOM"
body="$(printf '{"ref":"main","inputs":{"cle":"%s","ref":"%s","suites":"%s","captures":"%s","captures_quoi":"%s","mesures":"%s"}}' "$cle" "$ref" "$suites" "$captures" "$quoi" "$mesures")"
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
    printf '{"ref":"%s","suites":"%s","captures":%s,"captures_quoi":"%s","mesures":%s}\n' "$ref" "$suites" "$captures" "$quoi" "$mesures" > ci/en-ligne.json
    git add -f ci/en-ligne.json .github/workflows/a-la-demande.yml ci/en-ligne-run.sh
    git -c user.name=en-ligne -c user.email=en-ligne@users.noreply.github.com commit -q -m "chore: test en ligne temporaire ($ref)" || exit 1
    git push -q origin "HEAD:refs/heads/$branche"
  ) || { echo "Push de secours refusé." >&2; git worktree remove --force "$tmp/w" 2>/dev/null; rm -rf "$tmp"; exit 1; }
  git worktree remove --force "$tmp/w" 2>/dev/null; rm -rf "$tmp"
  echo "Lancé (push $branche) : ref=$ref suites='${suites}' captures=$captures mesures=$mesures"
fi
nettoyer() { [[ -n "$branche" ]] && gh api -X DELETE "repos/$repo/git/refs/heads/$branche" >/dev/null 2>&1 && echo "Branche temporaire $branche supprimée."; }
trap nettoyer EXIT

# Le workflow supprime lui-même la branche de repli (la session ne peut pas le faire) ; l'essai ci-dessous
# est facultatif et silencieux.
# Retrouver l'exécution créée après le déclenchement.
run=""
for _ in $(seq 1 12); do
  sleep 5
  if [[ -n "$branche" ]]; then
    run="$(gh api "repos/$repo/actions/workflows/$wf/runs?event=push&branch=$branche&per_page=1" --jq '.workflow_runs[0].id // empty' 2>/dev/null)"
  else
    run="$(gh api "repos/$repo/actions/workflows/$wf/runs?event=workflow_dispatch&created=>=$debut&per_page=30" --jq "[.workflow_runs[] | select(.display_title | contains(\"$cle\"))] | last | .id // empty" 2>/dev/null)"
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
# Résultats publiés par git (le job « publier » finit après le job de tests : courte attente).
recupere=false
for _ in $(seq 1 12); do
  if git fetch -q --depth=1 origin resultats-en-ligne 2>/dev/null \
     && git cat-file -e "FETCH_HEAD:runs/$run/meta.txt" 2>/dev/null; then
    git archive FETCH_HEAD "runs/$run" | tar -x -C "$dest" --strip-components=2 && recupere=true
    break
  fi
  sleep 10
done
if [[ $recupere != true ]]; then
  echo "Résultats absents de la branche resultats-en-ligne (échec avant les tests ?). Journal : gh run view $run --repo $repo --log-failed" >&2
fi
echo "Conclusion : $conclusion · résultats : $dest (artefact 7 jours sur la page du run)"
[[ -f "$dest/resume.md" ]] && cat "$dest/resume.md"
[[ -f "$dest/echecs.txt" ]] && { echo "--- Échecs ---"; cat "$dest/echecs.txt"; }
[[ "$conclusion" == success ]]
