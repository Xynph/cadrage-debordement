#!/usr/bin/env bash
# Lance des suites natives Godot avec le SDK obligatoire.
# Usage : bash ci/run-godot-suites.sh <fichier-liste-des-suites> [titre]
#   - CD_GODOT_EXECUTABLE ou CD_GODOT_EXE : exécutable Godot 4.7.2 (les deux sont
#     renseignés pour chaque suite par ci/godot-env.cjs, préchargé via NODE_OPTIONS) ;
#   - une suite qui se saute faute de moteur (« SDK Godot requis », etc.) ÉCHOUE ;
#   - à lancer sous un serveur X virtuel pour les rendus fenêtrés, par exemple :
#     xvfb-run -a -s "-screen 0 1920x1080x24" bash ci/run-godot-suites.sh liste.txt
# Sortie : une ligne PASS/ECHEC par suite, CD_CPU_PROFILE (poids des shards), et un
# tableau Markdown dans $GITHUB_STEP_SUMMARY (ou sur la sortie standard hors CI).
set -uo pipefail
list="${1:?Usage : ci/run-godot-suites.sh <liste> [titre]}"
title="${2:-Suites Godot}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mapfile -t suites < "$list"
[[ "${#suites[@]}" -gt 0 ]] || { echo "Aucune suite dans $list" >&2; exit 1; }
export CD_GODOT_REQUIRED=1
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--require=$root/ci/godot-env.cjs"
node "$root/ci/godot-env.cjs" --check || exit 1
work="$(mktemp -d)"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
# Motifs des sauts « faute de moteur » écrits par les suites (node:test TAP ou console).
engine_skip='SDK Godot (requis|absent)|Godot SDK required|SKIP [^ ]+ : SDK absent|SDK et worker knowledge requis|Set CD_GODOT_EXECUTABLE|NON EXÉCUTÉ \(CD_GODOT'
failures=0; executed=0; other_skips=0
: > "$work/results.md"
for test in "${suites[@]}"; do
  executed=$((executed+1))
  echo "::group::$test"
  start=$SECONDS
  limit="${CD_GODOT_SUITE_LIMIT:-300}s"
  log="$work/$(basename "$test").log"
  t0="$(date +%s%N)"
  if [[ -x /usr/bin/time ]]; then
    timeout --signal=TERM --kill-after=10s "$limit" /usr/bin/time -f "CD_CPU_PROFILE suite=$test user_s=%U system_s=%S wall_s=%e cpu_pct=%P max_rss_kb=%M" \
      node "$test" > "$log" 2>&1
    code=$?
  else
    timeout --signal=TERM --kill-after=10s "$limit" node "$test" > "$log" 2>&1
    code=$?
    t1="$(date +%s%N)"
    printf 'CD_CPU_PROFILE suite=%s wall_s=%d.%02d\n' "$test" $(( (t1-t0)/1000000000 )) $(( (t1-t0)/10000000%100 )) >> "$log"
  fi
  cat "$log"
  verdict=OK
  if [[ $code -ne 0 ]]; then
    verdict="ECHEC ($code)"
  elif grep -Eq "$engine_skip" "$log"; then
    verdict='ECHEC (saut faute de moteur)'
    grep -E "$engine_skip" "$log" | head -3
  fi
  skips="$(grep -Ec '^ *ok [0-9]+ .*# SKIP' "$log" || true)"
  [[ "$skips" -gt 0 && "$verdict" == OK ]] && other_skips=$((other_skips+skips))
  if [[ "$verdict" == OK ]]; then
    echo "PASS $test ($((SECONDS-start)) s)"
  else
    failures=$((failures+1))
    echo "::error file=$test::Godot : $verdict, durée $((SECONDS-start)) s, limite $limit"
  fi
  echo "| $test | $verdict | $((SECONDS-start)) s |" >> "$work/results.md"
  echo "::endgroup::"
done
{
  echo "### $title : $executed suites, $failures échec(s)"
  echo "| Suite | Résultat | Durée |"
  echo "| --- | --- | --- |"
  cat "$work/results.md"
  echo ""
  echo "Sauts déclarés pour d'autres raisons (plateforme, outil manuel) : $other_skips"
} >> "$summary"
rm -rf "$work"
[[ "$failures" -eq 0 ]]
