#!/usr/bin/env bash
# Lance la mesure Monde sur 10 graines en ligne (workflow .github/workflows/mesure-monde.yml) et rapatrie les résultats.
# Usage : bash ci/mesure-monde.sh <nom> [ref=HEAD]      → affiche le run_id puis, à la fin, le dossier /tmp/mesure-monde/<nom>
#         node scripts/compare-mesure-monde.cjs /tmp/mesure-monde/<avant> /tmp/mesure-monde/<apres>   → tableau avant/après
# Si la ref ne contient pas le workflow (ex. main avant sa fusion), il est ajouté dans un commit temporaire de la branche
# mesure-monde/<nom>-<horodatage>, supprimée par le workflow à la fin. Nécessite gh (authentifié) et un dépôt local.
set -euo pipefail
nom="${1:?Usage : mesure-monde.sh <nom> [ref]}"; ref="${2:-HEAD}"
[[ "$nom" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Nom invalide : $nom" >&2; exit 2; }
repo="Xynph/cadrage-debordement"; racine="$(git rev-parse --show-toplevel)"; wf=".github/workflows/mesure-monde.yml"
branche="mesure-monde/$nom-$(date -u +%Y%m%d%H%M%S)"
sha="$(git rev-parse "$ref^{commit}")"
if ! git cat-file -e "$sha:$wf" 2>/dev/null; then
  arbre="$(mktemp -d)"; git worktree add -q --detach "$arbre" "$sha"
  mkdir -p "$arbre/.github/workflows" && cp "$racine/$wf" "$arbre/$wf"
  git -C "$arbre" add "$wf" && git -C "$arbre" -c user.name=mesure -c user.email=mesure@localhost commit -q -m "mesure: workflow temporaire"
  sha="$(git -C "$arbre" rev-parse HEAD)"; git worktree remove --force "$arbre"
fi
git -c push.negotiate=true push -q origin "$sha:refs/heads/$branche"
echo "Branche $branche poussée ($sha), attente du run…"
run=""; for _ in $(seq 1 40); do
  run="$(gh api "repos/$repo/actions/runs?branch=$branche&event=push&per_page=5" -q '.workflow_runs[] | select(.path==".github/workflows/mesure-monde.yml") | .id' | head -1)"
  [[ -n "$run" ]] && break; sleep 15
done
[[ -n "$run" ]] || { echo "Run introuvable pour $branche" >&2; exit 1; }
echo "run_id=$run"
while :; do
  etat="$(gh api "repos/$repo/actions/runs/$run" -q '.status + " " + (.conclusion // "")')"
  [[ "$etat" == completed* ]] && break; sleep 30
done
echo "Run $run : $etat"
dest="/tmp/mesure-monde/$nom"; mkdir -p "$dest"
for _ in $(seq 1 20); do
  git fetch -q --depth=1 origin resultats-en-ligne 2>/dev/null || true
  if git cat-file -e "FETCH_HEAD:runs/$run" 2>/dev/null; then
    for f in $(git ls-tree --name-only "FETCH_HEAD:runs/$run"); do git show "FETCH_HEAD:runs/$run/$f" > "$dest/$f"; done
    echo "Résultats dans $dest ($(ls "$dest" | grep -c '^g.*\.json$') graines)"; exit 0
  fi
  sleep 15
done
echo "Résultats non publiés pour le run $run" >&2; exit 1
