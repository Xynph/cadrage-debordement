#!/usr/bin/env bash
# Exécute les suites d'un shard « Suites i/N » (liste produite par ci/shard-tests.cjs).
# Usage : bash ci/run-shard-suites.sh <liste> <titre> [suites-en-parallèle]
#   - suites-en-parallèle (défaut 1) : les suites sont mono-cœur (cpu_pct ≈ 100 %) et
#     les machines GitHub en ont 4 ; 2 en parallèle exploite le runner sans le saturer.
#     La liste arrive par poids décroissant : les plus longues démarrent en premier.
#   - chaque suite garde son délai maximal propre (budgets ci-dessous) ;
#   - journal groupé par suite, ligne CD_CPU_PROFILE (poids des shards, ci/suite-weights.cjs),
#     ligne « PASS tests/x.cjs (N s) » (ci/ci-run-metrics.cjs), tableau Markdown dans
#     $GITHUB_STEP_SUMMARY (sortie standard hors CI). Code de sortie 1 si une suite échoue.
set -uo pipefail
list="${1:?Usage : bash ci/run-shard-suites.sh <liste> <titre> [parallèle]}"
title="${2:?titre requis}"
parallel="${3:-1}"
[[ "$parallel" =~ ^[1-8]$ ]] || { echo "Parallélisme invalide : $parallel (1 à 8)" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mapfile -t suites < "$list"
[[ "${#suites[@]}" -gt 0 ]] || { echo "Aucune suite dans $list" >&2; exit 1; }
work="$(mktemp -d)"
mkdir -p "$work/logs" "$work/running"
: > "$work/results.md"
export CD_SHARD_WORK="$work"

budget() {
  # Budgets ciblés de réception cumulative, distincts des poids de planification.
  # Support a terminé en 883/941 s avant optimisation ; Nationale22 en 237,6 s.
  # Les autres réserves longues sont provisoires après les timeouts observés sur
  # 42891746395, sans retirer de contrôle.
  case "$1" in
    tests/world-worker-season.cjs) echo 1200s ;;
    tests/native-manager-career-worker.cjs|tests/native-manager-career-reverse.cjs) echo 900s ;;
    tests/native-academy-integrated-long.cjs) echo 1800s ;;
    tests/native-delegate-transaction06.cjs|tests/native-contextual-integration.cjs) echo 600s ;;
    tests/native-nationale-reduced-bench.cjs|tests/native-match-talks.cjs|tests/godot-roster-foundation.cjs) echo 300s ;;
    tests/native-club-support-season.cjs) echo 1200s ;;
    tests/native-club-world-worker.cjs) echo 900s ;;
    tests/native-club-strategy.cjs) echo 600s ;;
    tests/native-press-season.cjs|tests/native-press-personalities-worker.cjs) echo 900s ;;
    tests/deepen-staff-native.cjs) echo 1200s ;;
    tests/custom-competition-worker.cjs) echo 900s ;;
    # Réception locale complète 233 s ; conserve créations, Rooms et refus.
    tests/youth-scout-native.cjs) echo 600s ;;
    # Fixtures complètes PASS locales 142/126 s, sans refus précoce.
    tests/world-catalogue-dedup.cjs|tests/world-venue-media.cjs) echo 300s ;;
    tests/career-variation-worker.cjs|tests/management-day-worker.cjs) echo 600s ;;
    # PASS CI 42909005768 : 179,80/159,68 s, marge finie avant le cap 180.
    tests/france-career.cjs|tests/world-worker.cjs) echo 300s ;;
    tests/progression-policies.cjs|tests/native-academy-groups.cjs|tests/profile-safety-worker.cjs) echo 420s ;;
    *) echo 180s ;;
  esac
}

run_one() {
  local test="$1" work="$CD_SHARD_WORK" name limit start code verdict log
  name="$(basename "$test")"
  log="$work/logs/$name.log"
  limit="$(budget "$test")"
  touch "$work/running/$name"
  start=$SECONDS
  local t0 timer=()
  t0="$(date +%s%N)"
  [[ -x /usr/bin/time ]] && timer=(/usr/bin/time -f "CD_CPU_PROFILE suite=$test user_s=%U system_s=%S wall_s=%e cpu_pct=%P max_rss_kb=%M")
  if timeout --signal=TERM --kill-after=10s "$limit" "${timer[@]}" node "$test" > "$log" 2>&1; then
    code=0; verdict=OK
  else
    code=$?; verdict="ECHEC ($code)"
  fi
  local elapsed=$((SECONDS-start)) t1
  if [[ ${#timer[@]} -eq 0 ]]; then
    t1="$(date +%s%N)"
    printf 'CD_CPU_PROFILE suite=%s wall_s=%d.%02d\n' "$test" $(( (t1-t0)/1000000000 )) $(( (t1-t0)/10000000%100 )) >> "$log"
  fi
  rm -f "$work/running/$name"
  {
    flock 9
    echo "::group::$test"
    cat "$log"
    if [[ $code -eq 0 ]]; then
      echo "PASS $test ($elapsed s)"
    else
      echo "::error file=$test::Échec ou délai dépassé (code $code, durée $elapsed s, limite $limit)"
    fi
    echo "::endgroup::"
    echo "| $test | $verdict | $elapsed s |" >> "$work/results.md"
  } 9> "$work/print.lock"
  rm -f "$log"
}
export -f run_one budget

# Les dernières suites en cours restent visibles dans les annotations même si le runner
# est interrompu avant le résumé final.
interrupted() {
  for f in "$work"/running/*; do
    [[ -e "$f" ]] && printf '::error file=tests/%s::Interruption %s pendant la suite tests/%s\n' "$(basename "$f")" "$1" "$(basename "$f")"
  done
  exit "$2"
}
trap 'interrupted SIGTERM 143' TERM
trap 'interrupted SIGINT 130' INT

printf '%s\0' "${suites[@]}" | xargs -0 -P "$parallel" -I{} bash -c 'run_one "$1"' _ {} &
wait $!
executed="$(wc -l < "$work/results.md")"
failures="$(grep -c '| ECHEC' "$work/results.md" || true)"
total="$(find tests -maxdepth 1 -name '*.cjs' ! -name 'harness.cjs' | wc -l)"
{
  echo "### $title : $executed suites sur $total ($parallel en parallèle)"
  echo "| Suite | Résultat | Durée |"
  echo "| --- | --- | --- |"
  cat "$work/results.md"
  echo ""
  echo "**Échecs : $failures**"
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
rm -rf "$work"
[[ "$failures" -eq 0 && "$executed" -eq "${#suites[@]}" ]]
