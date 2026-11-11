#!/usr/bin/env bash
# Lance toutes les suites tests/*.cjs comme la CI (budgets identiques), 2 en parallèle.
# Usage : run-all-tests.sh <worktree> <dossier-resultats>
set -u
WT="$1"; OUT="$2"; mkdir -p "$OUT/logs"
export CD_GODOT_EXECUTABLE=/home/claude/outils/Godot_v4.7.2-stable_linux.x86_64
export CD_GODOT_EXE="$CD_GODOT_EXECUTABLE"
cd "$WT"
budget() {
  case "$1" in
    tests/world-worker-season.cjs|tests/native-club-support-season.cjs|tests/deepen-staff-native.cjs) echo 1200 ;;
    tests/native-academy-integrated-long.cjs) echo 1800 ;;
    tests/native-manager-career-worker.cjs|tests/native-manager-career-reverse.cjs|tests/native-club-world-worker.cjs|tests/native-press-season.cjs|tests/native-press-personalities-worker.cjs|tests/custom-competition-worker.cjs) echo 900 ;;
    tests/native-delegate-transaction06.cjs|tests/native-contextual-integration.cjs|tests/native-club-strategy.cjs|tests/career-variation-worker.cjs|tests/management-day-worker.cjs) echo 600 ;;
    tests/progression-policies.cjs|tests/native-academy-groups.cjs|tests/profile-safety-worker.cjs) echo 420 ;;
    tests/native-nationale-reduced-bench.cjs|tests/native-match-talks.cjs|tests/godot-roster-foundation.cjs) echo 300 ;;
    *) echo 180 ;;
  esac
}
run_one() {
  t="$1"; name=$(basename "$t" .cjs); lim=$(budget "$t"); s=$(date +%s)
  timeout --signal=TERM --kill-after=10s "$lim" xvfb-run -a -s "-screen 0 1920x1080x24" node "$t" > "$OUT/logs/$name.log" 2>&1
  code=$?; d=$(( $(date +%s) - s ))
  if [ $code -eq 0 ]; then r=PASS; elif [ $code -eq 124 ] || [ $code -eq 137 ]; then r=TIMEOUT; else r=FAIL; fi
  printf "%s\t%s\t%s\t%s\n" "$r" "$t" "$d" "$code" >> "$OUT/results.tsv"
}
export -f run_one budget; export OUT
touch "$OUT/results.tsv"
# Reprise : ignore les suites déjà consignées.
grep -vxF -f <(cut -f2 "$OUT/results.tsv") "$LIST" | xargs -P "${PAR:-1}" -I{} bash -c 'run_one "$@"' _ {}
echo DONE > "$OUT/done"
