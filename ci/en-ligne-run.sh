#!/usr/bin/env bash
# Exécute, sur un runner GitHub, les phases demandées par .github/workflows/a-la-demande.yml.
# Usage (variables d'environnement) : CD_EL_SUITES="a b" CD_EL_CAPTURES=true|false [CD_EL_CAPTURES_QUOI="intro,finitions,..."] CD_EL_MESURES=true|false
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
  # Délai par phase (CD_EL_PHASE_MIN, 40 min) : un blocage laisse un diagnostic au lieu d'un job tué sans trace.
  timeout --kill-after=30s "${CD_EL_PHASE_MIN:-40}m" "$@" > "$log" 2>&1; local code=$?
  [[ $code -eq 124 ]] && echo "ARRET : phase interrompue après ${CD_EL_PHASE_MIN:-40} min" >> "$log"
  if [[ $code -eq 0 ]]; then echo "- OK : $name ($((SECONDS-t)) s)" >> "$out/resume.md"
  else
    failed=1; echo "- ECHEC ($code) : $name ($((SECONDS-t)) s), journal $2" >> "$out/resume.md"
    echo "$2" >> "$out/journaux-echec.txt"
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
  # CD_EL_CAPTURES_QUOI : liste séparée par des virgules ou espaces parmi intro, finitions, fiche-club,
  # feuille-espoir, match-rendu, comparateur, audio, reception, creation, derby, equipe ; vide ou « toutes » = intro, finitions, fiche-club, feuille-espoir ; match-rendu (40 passes, 57 min sous llvmpipe :
  # à demander explicitement ; sans GPU, Forward+ n'existe pas, donc seules les passes « actuel » en 1280x720). comparateur et audio : aussi à demander explicitement.
  quoi=" $(echo "${CD_EL_CAPTURES_QUOI:-}" | tr ',' ' ') "
  [[ "$quoi" =~ ^[[:space:]]*$ || "$quoi" == *" toutes "* ]] && quoi=" intro finitions fiche-club feuille-espoir "
  for q in $quoi; do
    case "$q" in intro|finitions|fiche-club|feuille-espoir|match-rendu|comparateur|audio|reception|creation|derby|avis-staff|meteo|banque-images|prolongations-staff|investissements|sante|proprietaire|regles-fin|equipeancieres|pilotage|vestiaire) ;;
      *) echo "Capture inconnue : $q" >> "$out/echecs.txt"; echo "- ECHEC : capture inconnue $q" >> "$out/resume.md"; failed=1 ;; esac
  done
  veut() { [[ "$quoi" == *" $1 "* ]]; }
  cap="$out/captures"; mkdir -p "$cap"
  if veut intro; then
    mkdir -p "$cap/intro"
    if [[ -f tests/godot-intro.cjs ]]; then
      phase "captures intro (prologue, stade, titre)" captures-intro.log \
        env CD_INTRO_GRAPHICS=1 CD_INTRO_CAPTURES="$cap/intro" node tests/godot-intro.cjs
    else
      echo "- IGNORE : captures intro (tests/godot-intro.cjs absent de la branche testée)" >> "$out/resume.md"
    fi
  fi
  if veut finitions; then
    mkdir -p "$cap/finitions"
    phase "captures finitions (fiche joueur, Gabi, Continuer, calendrier)" captures-finitions.log \
      env CD_FINITIONS_CAPTURE="$cap/finitions/ecran-" CD_FINITIONS_OUTPUT="$cap/finitions" node tests/godot-finitions.cjs
  fi
  if veut fiche-club; then
    mkdir -p "$cap/fiche-club"
    phase "captures fiche club (1080p)" captures-fiche-club.log \
      env CD_FICHE_CAPTURES=1 CD_FICHE_OUTPUT="$cap/fiche-club" node tests/godot-fiche-club.cjs
  fi
  if veut feuille-espoir; then
    mkdir -p "$cap/feuille-espoir"
    phase "captures feuille espoir" captures-feuille-espoir.log \
      env CD_ESPOIR_CAPTURE="$cap/feuille-espoir/ecran-" node tests/godot-feuille-espoir.cjs
  fi
  if veut reception; then
    mkdir -p "$cap/reception"
    phase "captures Réception (1920x1080, 1280x720)" captures-reception.log \
      env CD_COURRIER_CAPTURES="$cap/reception" node tests/godot-courrier-club.cjs
  fi
  if veut match-rendu; then
    mkdir -p "$cap/match-rendu"
    phase "captures rendu de match" captures-match-rendu.log \
      env CD_MATCH_RENDU_CAPTURES="$cap/match-rendu" CD_MATCH_RENDU_PASSES=actuel CD_MATCH_RENDU_TAILLES=1280x720 node tests/godot-match-rendu-capture.cjs
  fi
  if veut meteo; then
    mkdir -p "$cap/meteo"
    phase "captures météo et vent (écran Match avant-match, vestiaire, bandeau, mi-temps, 1080p)" captures-meteo.log \
      env CD_METEO_GRAPHICS=1 CD_METEO_OUTPUT="$cap/meteo" node tests/godot-meteo-vent.cjs
  fi
  if veut pilotage; then
    mkdir -p "$cap/pilotage"
    phase "captures pilotage du match (écran 2D : faits marquants, états des joueurs, 720p/1080p/1440p)" captures-pilotage.log \
      env CD_MATCH_TEMPS_FORTS_CAPTURES="$cap/pilotage" CD_MATCH_TEMPS_FORTS_MODES=terrain2d node tests/godot-match-temps-forts.cjs
  fi
  if veut equipe; then
    mkdir -p "$cap/equipe"
    phase "captures fenêtre Équipe du match (Composition et Consignes ; 1080p et 720p, contrôles en 1440p)" captures-equipe.log \
      env CD_EQUIPE_GRAPHICS=1 CD_EQUIPE_OUTPUT="$cap/equipe" node --test tests/godot-fenetre-equipe.cjs
  fi
  if veut vestiaire; then
    mkdir -p "$cap/vestiaire"
    phase "captures vestiaire (causerie avant la décision, six tons ; après, réactions colorées ; 1080p et 720p)" captures-vestiaire.log \
      env CD_CONTEXTUAL_GRAPHICS=1 CD_CONTEXTUAL_ONLY=ui CD_CONTEXTUAL_ARTIFACTS="$cap/vestiaire/artefacts" CD_VESTIAIRE_OUTPUT="$cap/vestiaire" node tests/godot-contextual.cjs
  fi
  if veut banque-images; then
    mkdir -p "$cap/banque-images"
    phase "captures banque d'images (faits marquants, fin de match, stades, maillots recolorés, 1080p)" captures-banque-images.log \
      env CD_BANQUE_GRAPHICS=1 CD_BANQUE_OUTPUT="$cap/banque-images" node tests/godot-banque-images.cjs
  fi
  if veut avis-staff; then
    mkdir -p "$cap/avis-staff"
    phase "captures avis du staff (Composition, 1080p)" captures-avis-staff.log \
      env CD_AVIS_GRAPHICS=1 CD_AVIS_OUTPUT="$cap/avis-staff" node tests/godot-avis-staff.cjs
  fi
  if veut prolongations-staff; then
    mkdir -p "$cap/prolongations-staff"
    phase "capture prolongations au staff (vraie carrière, Effectif > Contrats, 1080p)" captures-prolongations-staff.log \
      env CD_PROLONGATIONS_GRAPHICS=1 CD_PROLONGATIONS_OUTPUT="$cap/prolongations-staff" node --test tests/godot-prolongations-staff-carriere.cjs
  fi
  if veut investissements; then
    mkdir -p "$cap/investissements"
    phase "captures excédents réinvestis (Club > Infrastructures, Finances ; 1080p)" captures-investissements.log \
      env CD_INVEST_GRAPHICS=1 CD_INVEST_OUTPUT="$cap/investissements" node --test tests/godot-investissements-excedents.cjs
  fi
  if veut sante; then
    mkdir -p "$cap/sante"
    phase "captures santé financière (Finances > Classement, fiche club ; 1080p)" captures-sante.log \
      env CD_SANTE_GRAPHICS=1 CD_SANTE_OUTPUT="$cap/sante" node --test tests/godot-sante-financiere.cjs
  fi
  if veut proprietaire; then
    mkdir -p "$cap/proprietaire"
    phase "captures argent du propriétaire (Réception : prêt, nouveau propriétaire ; Finances ; 1080p)" captures-proprietaire.log \
      env CD_PROPRIO_GRAPHICS=1 CD_PROPRIO_OUTPUT="$cap/proprietaire" node --test tests/godot-argent-proprietaire.cjs
  fi
  if veut regles-financieres; then
    mkdir -p "$cap/regles-financieres"
    phase "captures A2R et président (courriers en Réception ; 1080p)" captures-regles-financieres.log \
      env CD_A2R_GRAPHICS=1 CD_A2R_OUTPUT="$cap/regles-financieres" node --test tests/godot-a2r-president.cjs
  fi
  if veut comparateur; then
    mkdir -p "$cap/comparateur"
    phase "captures comparateur de joueurs (Effectif, fiche joueur, marché ; 1440p et 720p)" captures-comparateur.log \
      env CD_COMPARATEUR_CAPTURE="$cap/comparateur" node --test tests/godot-comparateur-joueurs.cjs
  fi
  if veut creation; then
    mkdir -p "$cap/creation"
    phase "captures création (choix du club, options de carrière ; 1080p)" captures-creation.log \
      env CD_REPRISE_UI_GRAPHICS=1 CD_REPRISE_UI_OUTPUT="$cap/creation" node --test tests/godot-reprise.cjs
  fi
  if veut derby; then
    mkdir -p "$cap/derby"
    phase "captures étiquette Derby (Bureau, Composition, Préparation ; 1080p)" captures-derby.log \
      env CD_DERBY_GRAPHICS=1 CD_DERBY_OUTPUT="$cap/derby" node tests/godot-derby-etiquette.cjs
  fi
  if veut audio; then
    mkdir -p "$cap/audio"
    phase "captures paramètres (onglets Son et Raccourcis clavier)" captures-audio.log \
      env CD_AMBIANCE_CAPTURE="$cap/audio" node --test tests/godot-ambiance.cjs
  fi
  echo "- Captures PNG :$(echo "$quoi" | tr -s ' ') $(find "$cap" -name '*.png' | wc -l) fichier(s)" >> "$out/resume.md"
fi

# 3. Mesures : parcours des écrans principaux (CD_MESURE en JSON) et portraits progressifs.
if [[ "${CD_EL_MESURES:-false}" == "true" ]]; then
  export CD_NODE_EXECUTABLE="$(command -v node)"
  data="$(mktemp -d)"
  trap '[[ "${CD_KEEP_TMP:-0}" == 1 ]] || rm -rf "$data"' EXIT
  phase "mesure du parcours des écrans (tests/godot-chargement-mesure.gd)" mesures-parcours.log \
    env CD_GODOT_TIMING=1 CD_GODOT_DATA_DIR="$data/PrototypeGodot" "$CD_GODOT_EXECUTABLE" --headless --audio-driver Dummy --path native/godot --script "$root/tests/godot-chargement-mesure.gd"
  [[ "${CD_KEEP_TMP:-0}" == 1 ]] || rm -rf "$data"
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

[[ -s "$out/echecs.txt" ]] || rm -f "$out/echecs.txt"
exit $failed
