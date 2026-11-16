#!/usr/bin/env bash
# Publie le dossier de résultats d'un run « à la demande » dans la branche orpheline
# `resultats-en-ligne`, sous runs/<run_id>/, avec un commit par run.
# Usage : bash ci/en-ligne-publier.sh <dossier-resultats> <run_id> <url-du-depot>
# Authentification : variables GIT_CONFIG_* du workflow (jeton GITHUB_TOKEN), rien n'est lu ici.
# - PNG réduits à 1280 px de large max et convertis en JPEG (qualité 80) ; journaux tronqués.
# - Dossiers de plus de 7 jours supprimés (date lue dans meta.txt).
# - Historique cumulé > CD_EL_MAX_MO (200 par défaut) : branche réécrite en orpheline (7 derniers jours).
# - Push refusé (concurrence) : fetch puis nouvel essai (5 au plus).
set -uo pipefail
src="${1:?Usage : en-ligne-publier.sh <dossier> <run_id> <url>}"; run="${2:?run_id}"; url="${3:?url}"
[[ "$run" =~ ^[0-9]+$ ]] || { echo "run_id invalide : $run" >&2; exit 2; }
[[ -d "$src" ]] || { echo "Dossier de résultats absent : $src (rien à publier)"; exit 0; }
branche="resultats-en-ligne"
max_octets=$(( ${CD_EL_MAX_MO:-200} * 1024 * 1024 ))
jours="${CD_EL_JOURS:-7}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
stage="$work/stage"; mkdir -p "$stage"

# 1. Préparer le contenu : copie, réduction des PNG, troncature des textes.
cp -R "$src"/. "$stage"/
reduire_png() {
  local f="$1" out="${1%.png}.jpg"
  if python3 -c 'import PIL' 2>/dev/null; then
    python3 - "$f" "$out" <<'PY' || return 1
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
if im.width > 1280:
    im = im.resize((1280, max(1, round(im.height * 1280 / im.width))), Image.LANCZOS)
im.save(sys.argv[2], "JPEG", quality=80, optimize=True)
PY
  elif command -v convert >/dev/null; then
    convert "$f" -resize '1280x>' -quality 80 "$out" || return 1
  else
    return 1
  fi
  rm -f "$f"
}
while IFS= read -r -d '' f; do
  reduire_png "$f" || { echo "PNG non converti, retiré : ${f#$stage/}"; rm -f "$f"; }
done < <(find "$stage" -type f -iname '*.png' -print0)
# Journaux : 100 Ko de fin au plus ; autres fichiers texte : 500 Ko ; binaires restants > 1 Mo retirés.
while IFS= read -r -d '' f; do
  taille=$(stat -c %s "$f"); limite=$(( 500 * 1024 )); [[ "$f" == *.log ]] && limite=$(( 100 * 1024 ))
  case "$f" in *.jpg|*.jpeg) [[ $taille -gt $(( 1024 * 1024 )) ]] && rm -f "$f"; continue ;; esac
  if grep -Iq . "$f" 2>/dev/null || [[ $taille -eq 0 ]]; then
    if [[ $taille -gt $limite ]]; then
      { echo "[... tronqué : $taille octets, fin conservée ...]"; tail -c "$limite" "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  else
    [[ $taille -gt $(( 1024 * 1024 )) ]] && rm -f "$f"
  fi
done < <(find "$stage" -type f -print0)
now=$(date -u +%s)
printf 'run=%s\nepoch=%s\ndate=%s\n' "$run" "$now" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$stage/meta.txt"
ajout=$(du -sb "$stage" | cut -f1)

# 2. Pousser (avec reprise).
repo="$work/repo"; git init -q "$repo"
cd "$repo" || exit 1
git remote add origin "$url"
git config user.name "github-actions[bot]"; git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
for essai in 1 2 3 4 5; do
  existe=false; tip=""
  if git fetch -q --depth=1 origin "$branche" 2>/dev/null; then
    existe=true; tip="$(git rev-parse FETCH_HEAD)"
    git checkout -q -B "$branche" "$tip" || exit 1
  else
    git checkout -q --orphan "$branche"; git rm -rq --cached . 2>/dev/null || true
  fi
  # Ménage : dossiers de plus de N jours.
  limite=$(( now - jours * 86400 ))
  for d in runs/*/; do
    [[ -d "$d" ]] || continue
    ep="$(sed -n 's/^epoch=//p' "$d/meta.txt" 2>/dev/null | head -1)"
    if [[ ! "$ep" =~ ^[0-9]+$ || $ep -lt $limite ]]; then rm -rf "$d"; fi
  done
  cumul="$(cat .historique 2>/dev/null || echo 0)"; [[ "$cumul" =~ ^[0-9]+$ ]] || cumul=0
  reecrire=false
  if [[ $(( cumul + ajout )) -gt $max_octets ]]; then
    reecrire=true; cumul=$(du -sb runs 2>/dev/null | cut -f1); cumul="${cumul:-0}"
    echo "Branche > $((max_octets / 1048576)) Mo : réécriture en orpheline (${jours} derniers jours)."
  fi
  rm -rf "runs/$run"; mkdir -p "runs/$run"; cp -R "$stage"/. "runs/$run"/
  echo $(( cumul + ajout )) > .historique
  git add -A
  msg="chore: résultats en ligne run $run"
  if [[ $reecrire == true ]]; then
    git checkout -q --orphan "${branche}-tmp"; git add -A
    git commit -q -m "$msg (branche réécrite)"; git branch -q -M "$branche"
    lease="--force-with-lease=$branche:${tip}"; [[ $existe == true ]] || lease="--force"
    git push -q $lease origin "HEAD:refs/heads/$branche" && { echo "Publié (réécriture) : runs/$run"; exit 0; }
  else
    git commit -q -m "$msg"
    if git push -q origin "HEAD:refs/heads/$branche"; then echo "Publié : $branche runs/$run (+${ajout} octets)"; exit 0; fi
  fi
  echo "Push refusé (essai $essai/5), nouvelle tentative."; sleep $(( essai * 3 ))
  git checkout -q --detach 2>/dev/null; git branch -q -D "$branche" 2>/dev/null; git branch -q -D "${branche}-tmp" 2>/dev/null
done
echo "Publication impossible après 5 essais." >&2; exit 1
