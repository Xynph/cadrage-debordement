#!/usr/bin/env bash
# Exécute, sur un runner GitHub, les phases demandées par .github/workflows/a-la-demande.yml.
# Usage (variables d'environnement) : CD_EL_SUITES="a b" CD_EL_CAPTURES=true|false CD_EL_MESURES=true|false
#   bash ci/en-ligne-run.sh <dossier-de-sortie>
# À lancer sous xvfb, avec CD_GODOT_EXECUTABLE défini. Écrit resume.md, echecs.txt et les journaux
# dans le dossier de sortie ; sort en erreur si une phase échoue. Mode Monde uniquement.
set -uo pipefail
out="$(mkdir -p "${1:?Usage : ci/en-ligne-run.sh <dossier>}" && cd "$1" && pwd)"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export CD_GODOT_REQUIRED=1 CD_GODOT_SELF_TEST=0
unset CD_MODES_HERITES
failed=0
: > "$out/echecs.txt"
{ echo "## Tests en ligne : ${GITHUB_REF_NAME:-?} @ $(git rev-parse --short HEAD)"; echo; } > "$out/resume.md"

phase() { # phase <nom> <journal> <commande...>
  local name="$1" log="$out/$2"; shift 2
  local t=$SECONDS
  "$@" > "$log" 2>&1; local code=$?
  if [[ $code -eq 0 ]]; then echo "- OK : $name ($((SECONDS-t)) s)" >> "$out/resume.md"
  else
    failed=1; echo "- ECHEC ($code) : $name ($((SECONDS-t)) s), journal $2" >> "$out/resume.md"
    { echo "== $name (code $code)"; grep -E 'FAIL|ECHEC|Error|ERROR|not ok' "$log" | head -15; } >> "$out/echecs.txt"
  fi
}

# 1. Suites demandées (noms de tests/*.cjs, ou godot-xxx sans chemin ni extension).
if [[ -n "${CD_EL_SUITES// /}" ]]; then
  list="$out/suites.txt"; : > "$list"
  for s in $CD_EL_SUITES; do
    s="${s#tests/}"; s="${s%.cjs}"
    [[ "$s" =~ ^[A-Za-z0-9._-]+$ && -f "tests/$s.cjs" ]] || { echo "Suite inconnue : $s" >> "$out/echecs.txt"; echo "- ECHEC : suite inconnue $s" >> "$out/resume.md"; failed=1; continue; }
    echo "tests/$s.cjs" >> "$list"
  done
  if [[ -s "$list" ]]; then
    GITHUB_STEP_SUMMARY="$out/suites-resume.md" phase "suites ($(wc -l < "$list"))" suites.log bash ci/run-godot-suites.sh "$list" "Suites demandées"
    [[ -f "$out/suites-resume.md" ]] && cat "$out/suites-resume.md" >> "$out/resume.md"
  fi
fi

# 2. Captures : suites existantes qui savent écrire des PNG sous un affichage réel (carrière Monde).
#    Pas de séquence d'intro dédiée dans le dépôt : l'écran d'entrée n'a pas de suite de capture.
if [[ "${CD_EL_CAPTURES:-false}" == "true" ]]; then
  cap="$out/captures"; mkdir -p "$cap/finitions" "$cap/fiche-club" "$cap/feuille-espoir" "$cap/match-rendu"
  phase "captures finitions (fiche joueur, Gabi, Continuer, calendrier)" captures-finitions.log \
    env CD_FINITIONS_CAPTURE="$cap/finitions/ecran-" CD_FINITIONS_OUTPUT="$cap/finitions" node tests/godot-finitions.cjs
  phase "captures fiche club (1080p)" captures-fiche-club.log \
    env CD_FICHE_CAPTURES=1 CD_FICHE_OUTPUT="$cap/fiche-club" node tests/godot-fiche-club.cjs
  phase "captures feuille espoir" captures-feuille-espoir.log \
    env CD_ESPOIR_CAPTURE="$cap/feuille-espoir/ecran-" node tests/godot-feuille-espoir.cjs
  phase "captures rendu de match" captures-match-rendu.log \
    env CD_MATCH_RENDU_CAPTURES="$cap/match-rendu" node tests/godot-match-rendu-capture.cjs
  echo "- Captures PNG : $(find "$cap" -name '*.png' | wc -l) fichier(s)" >> "$out/resume.md"
fi

# 3. Mesures : parcours des écrans principaux (CD_MESURE en JSON) et portraits progressifs.
if [[ "${CD_EL_MESURES:-false}" == "true" ]]; then
  export CD_NODE_EXECUTABLE="$(command -v node)"
  data="$(mktemp -d)"
  phase "mesure du parcours des écrans (tests/godot-chargement-mesure.gd)" mesures-parcours.log \
    env CD_GODOT_TIMING=1 CD_GODOT_DATA_DIR="$data/PrototypeGodot" "$CD_GODOT_EXECUTABLE" --headless --audio-driver Dummy --path native/godot --script "$root/tests/godot-chargement-mesure.gd"
  rm -rf "$data"
  phase "portraits progressifs" mesures-portraits.log node tests/godot-portraits-progressifs.cjs
  if grep -h '^CD_MESURE ' "$out/mesures-parcours.log" 2>/dev/null | head -1 | sed 's/^CD_MESURE //' > "$out/mesure.json" && [[ -s "$out/mesure.json" ]]; then
    node -e '
      const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const nav = {}; for (const n of m.navigation || []) (nav[n.route] ||= []).push(n.rendu_ms);
      console.log("\n| Ecran | Ouverture moyenne (ms) | Max (ms) |\n| --- | --- | --- |");
      for (const [r, v] of Object.entries(nav)) console.log("| " + r + " | " + (v.reduce((a, b) => a + b, 0) / v.length).toFixed(1) + " | " + Math.max(...v).toFixed(1) + " |");
    ' "$out/mesure.json" >> "$out/resume.md"
  fi
fi

echo "=== LOT26 ==="; cat "$out/resume.md"; cat "$out/mesure.json" 2>/dev/null | head -c 20000; echo; tail -5 "$out/mesures-parcours.log" 2>/dev/null; grep -hE "LOT26_|FAIL" "$out"/*.log 2>/dev/null | head -80; cat "$out/echecs.txt" 2>/dev/null; echo "=== FIN LOT26 ==="
[[ -s "$out/echecs.txt" ]] || rm -f "$out/echecs.txt"
exit $failed
