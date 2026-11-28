#!/usr/bin/env bash
# PR rouge seulement par délai dépassé (runner lent) : relance UNE fois les jobs en échec (voir
# .github/workflows/relance-delai.yml, décision de Léo du 28/11/2026). Une assertion rouge n'est jamais
# relancée : la PR attend sa correction.
# Variables : GH_TOKEN, GITHUB_REPOSITORY, RUN_ID, ATTEMPT, ESSAI (true = aucune relance, verdict seul).
set -uo pipefail
REPO="${GITHUB_REPOSITORY:?}"
ESSAI="${ESSAI:-false}"
log() { echo "[relance-delai] $*"; }
# Marques d'un délai : suite coupée (timeout code 124), étape coupée à 45 min, délai interne de la VM du moteur.
DELAI='ECHEC \(124\)|code 124|has timed out after|Script execution timed out|ETIMEDOUT'

if (( ATTEMPT > 1 )); then log "déjà relancé (tentative $ATTEMPT) : rien à faire"; exit 0; fi
mapfile -t jobs < <(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100" \
  --jq '.jobs[] | select(.conclusion=="failure" and .name!="Validation CI") | "\(.id) \(.name)"')
(( ${#jobs[@]} )) || { log "aucun job en échec hors Validation CI"; exit 0; }
for entree in "${jobs[@]}"; do
  id="${entree%% *}"
  journal=$(gh api "repos/$REPO/actions/jobs/$id/logs" 2>/dev/null | grep -E '##\[error\]|^not ok' || true)
  if ! grep -qE "$DELAI" <<< "$journal"; then log "« ${entree#* } » : échec hors délai, pas de relance"; exit 0; fi
  # Une assertion rouge dans le même job (« not ok » d'une suite qui n'a pas expiré) : pas de relance.
  if grep -E '##\[error\]' <<< "$journal" | grep -vqE "$DELAI|Process completed with exit code"; then
    log "« ${entree#* } » : délai et autre échec mêlés, pas de relance"; exit 0
  fi
done
log "${#jobs[@]} job(s) rouges seulement par délai : relance unique"
[[ "$ESSAI" == "true" ]] || gh run rerun "$RUN_ID" --repo "$REPO" --failed || log "relance impossible"
