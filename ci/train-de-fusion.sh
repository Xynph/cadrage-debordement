#!/usr/bin/env bash
# Train de fusion : regroupe les PR étiquetées `train`, lance UNE batterie CI complète
# (tests.yml en workflow_dispatch, Godot compris) sur main + ces PR, puis fusionne le lot.
# Rouge : dichotomie — on reteste la première moitié ; verte, elle est fusionnée et le reste
# attend le train suivant ; une PR seule rouge passe en `train-echec`.
# Voir docs/train-de-fusion.md.
#
# Variables : GH_TOKEN, GITHUB_REPOSITORY, TAILLE_MAX (6), ESSAI (true = rien n'est poussé).
set -uo pipefail

REPO="${GITHUB_REPOSITORY:?}"
TAILLE_MAX="${TAILLE_MAX:-6}"
ESSAI="${ESSAI:-false}"
STAMP="$(date -u +%Y%m%d-%H%M)"
ATTENTE_MAX_S=$((100 * 60))   # une batterie complète dure ~25-35 min, file d'attente comprise
TABLEAU=591
RESUME="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

log() { echo "[train] $*"; }
resume() { echo "$*" >> "$RESUME"; }
commenter() { # $1 = numéro, $2 = texte
  [[ "$ESSAI" == "true" ]] && { log "(essai) commentaire #$1 : $2"; return; }
  gh api "repos/$REPO/issues/$1/comments" -f body="$2" >/dev/null || log "commentaire #$1 impossible"
}
etiquette_echec() { # $1 = numéro, $2 = raison
  [[ "$ESSAI" == "true" ]] && { log "(essai) #$1 → train-echec : $2"; return; }
  gh api -X DELETE "repos/$REPO/issues/$1/labels/train" >/dev/null 2>&1 || true
  gh api "repos/$REPO/issues/$1/labels" -f 'labels[]=train-echec' >/dev/null 2>&1 || true
  commenter "$1" "🚂 Train de fusion : PR retirée du train — $2
Corriger puis remettre l'étiquette \`train\` (et retirer \`train-echec\`)."
}

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# --- Candidates : PR ouvertes vers main, étiquette train, même dépôt, sans train-echec ---
mapfile -t CANDIDATES < <(gh api "repos/$REPO/pulls?state=open&base=main&per_page=100&sort=created&direction=asc" --jq \
  '.[] | select(any(.labels[]; .name=="train")) | select(all(.labels[]; .name!="train-echec"))
       | select(.head.repo.full_name=="'"$REPO"'") | .number')
CANDIDATES=("${CANDIDATES[@]:0:$TAILLE_MAX}")
resume "## 🚂 Train de fusion $STAMP"
if (( ${#CANDIDATES[@]} == 0 )); then
  log "aucune PR étiquetée train"; resume "Aucune PR étiquetée \`train\`."; exit 0
fi
log "candidates : ${CANDIDATES[*]}"

INCLUSES=()
# construire <branche> <PR...> : main + squash de chaque PR ; remplit INCLUSES.
construire() {
  local branche="$1"; shift
  INCLUSES=()
  git fetch -q origin main
  git checkout -q -B "$branche" origin/main
  local n titre auteur id
  for n in "$@"; do
    if ! git fetch -q origin "pull/$n/head:pr-$n" 2>/dev/null; then etiquette_echec "$n" "tête de PR introuvable."; continue; fi
    if ! git merge --squash -q "pr-$n" >/dev/null 2>&1; then
      git reset -q --hard HEAD
      etiquette_echec "$n" "conflit avec main ou avec une PR du même lot (${INCLUSES[*]:-aucune}). Mettre la branche à jour avec main."
      continue
    fi
    if git diff --cached --name-only | grep -q '^\.github/workflows/'; then
      git reset -q --hard HEAD
      etiquette_echec "$n" "elle modifie \`.github/workflows/\`, que le jeton du train ne peut pas pousser. Fusion classique : passer la PR en prête et activer la fusion automatique."
      continue
    fi
    if git diff --cached --quiet; then
      git reset -q --hard HEAD
      etiquette_echec "$n" "elle n'apporte plus aucun changement par rapport à main."
      continue
    fi
    titre=$(gh api "repos/$REPO/pulls/$n" --jq .title)
    auteur=$(gh api "repos/$REPO/pulls/$n" --jq '"\(.user.login) <\(.user.id)+\(.user.login)@users.noreply.github.com>"')
    git commit -q --author="$auteur" -m "$titre (#$n)" -m "Fusionné par le train de fusion $STAMP."
    INCLUSES+=("$n")
  done
}

# tester <branche> : batterie complète ; renvoie 0 si « Validation CI » est vert.
RUN_URL=""
tester() {
  local branche="$1" id="" debut=$SECONDS etat conclusion
  [[ "$ESSAI" == "true" ]] && { log "(essai) batterie non lancée"; return 1; }
  git push -q -f origin "$branche" || { log "push impossible"; return 2; }
  gh workflow run tests.yml --repo "$REPO" --ref "$branche" || return 2
  for _ in $(seq 1 30); do
    sleep 10
    id=$(gh run list --repo "$REPO" --workflow tests.yml --branch "$branche" --event workflow_dispatch \
      --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    [[ -n "$id" ]] && break
  done
  [[ -n "$id" ]] || { log "exécution introuvable"; return 2; }
  RUN_URL="https://github.com/$REPO/actions/runs/$id"
  log "batterie : $RUN_URL"
  while (( SECONDS - debut < ATTENTE_MAX_S )); do
    sleep 60
    etat=$(gh run view "$id" --repo "$REPO" --json status --jq .status)
    [[ "$etat" == "completed" ]] && break
  done
  conclusion=$(gh run view "$id" --repo "$REPO" --json jobs --jq '.jobs[] | select(.name=="Validation CI") | .conclusion')
  log "Validation CI : ${conclusion:-absente}"
  [[ "$conclusion" == "success" ]]
}

# fusionner <branche> : PR train → main, fusion en rebase (un commit par PR), clôture des PR d'origine.
fusionner() {
  local branche="$1" liste corps pr etat sha i
  liste=$(printf '#%s, ' "${INCLUSES[@]}"); liste="${liste%, }"
  corps="Lot du train de fusion $STAMP : $liste.
Batterie complète verte sur ce commit : $RUN_URL
Fusion en rebase : un commit par PR dans main."
  pr=$(gh api "repos/$REPO/pulls" -f title="Train de fusion $STAMP : $liste" -f head="$branche" -f base=main -f body="$corps" --jq .number) \
    || { log "création de la PR du train refusée (réglage « Allow GitHub Actions to create and approve pull requests » ?)"; return 1; }
  for i in $(seq 1 20); do
    etat=$(gh api "repos/$REPO/pulls/$pr" --jq '.mergeable_state')
    [[ "$etat" != "unknown" && -n "$etat" ]] && break
    sleep 6
  done
  sha=$(gh api -X PUT "repos/$REPO/pulls/$pr/merge" -f merge_method=rebase --jq .sha) \
    || { log "fusion de #$pr refusée (état : $etat)"; commenter "$pr" "Fusion refusée par GitHub (état : $etat)."; return 1; }
  log "fusionné : #$pr → $sha"
  for i in "${INCLUSES[@]}"; do
    commenter "$i" "🚂 Fusionné dans main par le train [#$pr](https://github.com/$REPO/pull/$pr) (\`${sha:0:8}\`), batterie complète : $RUN_URL"
    gh api -X PATCH "repos/$REPO/pulls/$i" -f state=closed >/dev/null || true
    ref=$(gh api "repos/$REPO/pulls/$i" --jq .head.ref)
    gh api -X DELETE "repos/$REPO/git/refs/heads/$ref" >/dev/null 2>&1 || true
  done
  commenter "$TABLEAU" "FUSIONNÉ : $liste — via le train #$pr — \`${sha:0:8}\`. Si une de ces PR change des données figées, sa passation le dit."
  # Une fusion par le jeton du dépôt ne déclenche pas les workflows « push sur main » : relancer la recette Windows RTX.
  gh workflow run windows-pc-leo-dispatch.yml --repo "$REPO" --ref main >/dev/null 2>&1 || log "recette Windows RTX non relancée"
  resume "✅ Fusionné via #$pr (\`${sha:0:8}\`) : $liste — [batterie]($RUN_URL)"
  return 0
}

# --- Boucle : lot complet, puis dichotomie sur la première moitié en cas de rouge ---
LOT=("${CANDIDATES[@]}")
essai=0
while (( ${#LOT[@]} > 0 )); do
  essai=$((essai + 1))
  branche="train/$STAMP-$essai"
  construire "$branche" "${LOT[@]}"
  (( ${#INCLUSES[@]} == 0 )) && { resume "Aucune PR intégrable dans ce lot."; break; }
  log "lot $essai : ${INCLUSES[*]}"
  tester "$branche"; verdict=$?
  if (( verdict == 0 )); then
    fusionner "$branche" || { resume "❌ Lot vert mais fusion impossible : ${INCLUSES[*]} (voir le journal)."; git push -q origin --delete "$branche" 2>/dev/null; exit 1; }
    break
  fi
  [[ "$ESSAI" != "true" ]] && git push -q origin --delete "$branche" 2>/dev/null
  if (( verdict == 2 )); then resume "❌ Batterie impossible à lancer (lot ${INCLUSES[*]})."; exit 1; fi
  [[ "$ESSAI" == "true" ]] && { resume "Essai : lot construit sans conflit : ${INCLUSES[*]}"; break; }
  resume "🔴 Lot rouge : ${INCLUSES[*]} — [batterie]($RUN_URL)"
  if (( ${#INCLUSES[@]} == 1 )); then
    etiquette_echec "${INCLUSES[0]}" "la batterie complète est rouge sur main + cette PR : $RUN_URL"
    break
  fi
  moitie=$(( ${#INCLUSES[@]} / 2 ))
  LOT=("${INCLUSES[@]:0:$moitie}")
  log "rouge : on reteste la première moitié (${LOT[*]}) ; les autres attendent le train suivant"
done
exit 0
