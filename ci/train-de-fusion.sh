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
declare -A TETES=()   # PR -> sha de la tête au moment de la construction du lot
RELANCE=""            # « oui » si le lot est passé au vert après relance des jobs en échec
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
    TETES[$n]=$(git rev-parse "pr-$n")
    INCLUSES+=("$n")
  done
}

# tester <branche> : pousse le lot, ouvre AUSSITÔT la PR du train (échec immédiat si GitHub
# refuse), puis attend la batterie complète que cette PR déclenche elle-même (tests.yml en
# pull_request, mêmes règles qu'une PR ordinaire). Repli : workflow_dispatch si aucune exécution
# n'apparaît. Renvoie 0 si « Validation CI » est vert, 1 si rouge, 2 si impossible.
RUN_URL=""; TRAIN_PR=""
tester() {
  local branche="$1" id="" debut=$SECONDS etat conclusion liste sha evt="pull_request"
  RELANCE=""; DIAG=""
  [[ "$ESSAI" == "true" ]] && { log "(essai) batterie non lancée"; return 1; }
  git push -q -f origin "$branche" || { log "push impossible"; return 2; }
  sha=$(git rev-parse HEAD)
  liste=$(printf '#%s, ' "${INCLUSES[@]}"); liste="${liste%, }"
  TRAIN_PR=$(gh api "repos/$REPO/pulls" -f title="Train de fusion $STAMP : $liste" -f head="$branche" -f base=main \
    -f body="Lot du train de fusion $STAMP : $liste. Fusion en rebase (un commit par PR) dès que « Validation CI » est vert. Voir docs/train-de-fusion.md." --jq .number) \
    || { log "création de la PR du train refusée (réglage « Allow GitHub Actions to create and approve pull requests » ?)"; return 2; }
  log "PR du train : #$TRAIN_PR"
  for _ in $(seq 1 18); do
    sleep 10
    id=$(gh run list --repo "$REPO" --workflow tests.yml --branch "$branche" --event pull_request \
      --limit 1 --json databaseId,headSha --jq '.[] | select(.headSha=="'"$sha"'") | .databaseId')
    [[ -n "$id" ]] && break
  done
  # Constaté le 18/11 : sur une PR ouverte par le jeton du dépôt, l'exécution pull_request de tests.yml
  # s'arrête en ~1 min sans aucun job (démarrage refusé). On la laisse finir, puis repli en dispatch.
  if [[ -n "$id" ]]; then
    for _ in $(seq 1 12); do
      etat=$(gh run view "$id" --repo "$REPO" --json status --jq .status)
      [[ "$etat" == "completed" ]] && break
      nb=$(gh api "repos/$REPO/actions/runs/$id/jobs" --jq '.jobs|length')
      (( nb > 0 )) && break
      sleep 10
    done
    nb=$(gh api "repos/$REPO/actions/runs/$id/jobs" --jq '.jobs|length')
    if [[ "$etat" == "completed" && "$nb" == "0" ]]; then log "exécution pull_request sans job (démarrage refusé) : repli"; id=""; fi
  fi
  if [[ -z "$id" ]]; then
    log "aucune batterie utilisable déclenchée par la PR : repli sur workflow_dispatch"; evt="workflow_dispatch"
    gh workflow run tests.yml --repo "$REPO" --ref "$branche" || return 2
    for _ in $(seq 1 30); do
      sleep 10
      id=$(gh run list --repo "$REPO" --workflow tests.yml --branch "$branche" --event workflow_dispatch \
        --limit 1 --json databaseId --jq '.[0].databaseId // empty')
      [[ -n "$id" ]] && break
    done
  fi
  [[ -n "$id" ]] || { log "exécution introuvable"; return 2; }
  RUN_URL="https://github.com/$REPO/actions/runs/$id"
  log "batterie ($evt) : $RUN_URL"
  attendre_fin "$id" "$debut"
  conclusion=$(gh run view "$id" --repo "$REPO" --json jobs --jq '.jobs[] | select(.name=="Validation CI") | .conclusion')
  log "Validation CI : ${conclusion:-absente}"
  # Un rouge peut venir d'un délai dépassé (runner lent), pas d'une assertion : on relance UNE fois les seuls
  # jobs en échec avant de conclure (et de couper le lot, ce qui coûte une batterie entière par coupe).
  if [[ "$conclusion" != "success" ]] && (( SECONDS - debut < ATTENTE_MAX_S )); then
    diagnostic "$id"
    log "relance unique des jobs en échec"
    if gh run rerun "$id" --repo "$REPO" --failed >/dev/null 2>&1; then
      sleep 45
      attendre_fin "$id" "$debut"
      conclusion=$(gh run view "$id" --repo "$REPO" --json jobs --jq '.jobs[] | select(.name=="Validation CI") | .conclusion')
      log "Validation CI après relance : ${conclusion:-absente}"
      [[ "$conclusion" == "success" ]] && RELANCE="oui"
    fi
  fi
  [[ "$conclusion" == "success" ]]
}

# attendre_fin <run> <début> : attend la fin de l'exécution (ou ATTENTE_MAX_S depuis <début>).
attendre_fin() {
  local id="$1" debut="$2" etat
  while (( SECONDS - debut < ATTENTE_MAX_S )); do
    sleep 60
    etat=$(gh run view "$id" --repo "$REPO" --json status --jq .status)
    [[ "$etat" == "completed" ]] && break
  done
}

# diagnostic <run> : DIAG = « délai dépassé » (code 124 / ETIMEDOUT dans les jobs en échec) ou « assertion rouge ».
DIAG=""
diagnostic() {
  local id="$1" noms
  noms=$(gh run view "$id" --repo "$REPO" --json jobs --jq '[.jobs[] | select(.conclusion=="failure") | .name] | join(", ")')
  if gh run view "$id" --repo "$REPO" --log-failed 2>/dev/null | grep -qE 'ETIMEDOUT|ECHEC \(124\)|exit code 124|timed out|dépass'; then
    DIAG="délai dépassé (jobs : ${noms:-?})"
  else
    DIAG="assertion rouge (jobs : ${noms:-?})"
  fi
  log "diagnostic : $DIAG"
}

# retirees : PR du lot dont l'étiquette `train` a été retirée, fermées ou dont la tête a changé depuis la construction.
retirees() {
  local n info
  RETIREES=()
  for n in "${INCLUSES[@]}"; do
    info=$(gh api "repos/$REPO/pulls/$n" --jq '[.state, ([.labels[].name] | index("train") != null), .head.sha] | @tsv' 2>/dev/null) || continue
    [[ "$info" == $'open\ttrue\t'"${TETES[$n]}" ]] || RETIREES+=("$n")
  done
}

# fusionner : fusion en rebase de la PR du train (un commit par PR), clôture des PR d'origine.
fusionner() {
  local liste pr="$TRAIN_PR" etat="" sha="" i ref
  liste=$(printf '#%s, ' "${INCLUSES[@]}"); liste="${liste%, }"
  # L'état de fusion se recalcule après la fin de la batterie : attendre « clean » ou « unstable »
  # (contrôle non obligatoire rouge, fusion permise), jusqu'à 5 min.
  for i in $(seq 1 30); do
    etat=$(gh api "repos/$REPO/pulls/$pr" --jq '.mergeable_state')
    [[ "$etat" == "clean" || "$etat" == "unstable" || "$etat" == "has_hooks" ]] && break
    sleep 10
  done
  for i in 1 2 3; do
    sha=$(gh api -X PUT "repos/$REPO/pulls/$pr/merge" -f merge_method=rebase --jq .sha 2>/tmp/fusion.err) && break
    sha=""; log "fusion de #$pr refusée (état : $etat) : $(cat /tmp/fusion.err)"; sleep 30
  done
  [[ -n "$sha" ]] || { commenter "$pr" "Fusion refusée par GitHub (état : $etat) : $(cat /tmp/fusion.err)"; return 1; }
  log "fusionné : #$pr → $sha"
  gh api -X PATCH "repos/$REPO/pulls/$pr" -f body="Lot du train de fusion $STAMP : $liste.
Batterie complète verte : $RUN_URL
Fusion en rebase : un commit par PR dans main." >/dev/null || true
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
    retirees
    if (( ${#RETIREES[@]} > 0 )); then
      log "PR retirée ou modifiée pendant le test : ${RETIREES[*]} — lot refait sans elle"
      resume "⚠️ Lot vert mais PR retirée/modifiée pendant le test (${RETIREES[*]}) : on refait le lot sans elle, rien n'est fusionné."
      gh api -X PATCH "repos/$REPO/pulls/$TRAIN_PR" -f state=closed >/dev/null 2>&1 || true
      git push -q origin --delete "$branche" 2>/dev/null
      LOT=(); for n in "${INCLUSES[@]}"; do [[ " ${RETIREES[*]} " == *" $n "* ]] || LOT+=("$n"); done
      (( ${#LOT[@]} > 0 )) && continue || break
    fi
    [[ -n "$RELANCE" ]] && resume "ℹ️ Lot passé au vert après relance des jobs en échec (rouge intermittent) : ${INCLUSES[*]}"
    fusionner || { resume "❌ Lot vert mais fusion impossible : ${INCLUSES[*]} — PR du train #$TRAIN_PR laissée ouverte pour une fusion à la main."; exit 1; }
    break
  fi
  [[ "$ESSAI" != "true" ]] && git push -q origin --delete "$branche" 2>/dev/null
  if (( verdict == 2 )); then resume "❌ Batterie impossible à lancer (lot ${INCLUSES[*]})."; exit 1; fi
  [[ "$ESSAI" == "true" ]] && { resume "Essai : lot construit sans conflit : ${INCLUSES[*]}"; break; }
  resume "🔴 Lot rouge (${DIAG:-cause inconnue}, après relance) : ${INCLUSES[*]} — [batterie]($RUN_URL)"
  if (( ${#INCLUSES[@]} == 1 )); then
    etiquette_echec "${INCLUSES[0]}" "la batterie complète reste rouge après relance (${DIAG:-cause inconnue}) sur main + cette PR : $RUN_URL"
    break
  fi
  moitie=$(( ${#INCLUSES[@]} / 2 ))
  LOT=("${INCLUSES[@]:0:$moitie}")
  log "rouge : on reteste la première moitié (${LOT[*]}) ; les autres attendent le train suivant"
done
exit 0
