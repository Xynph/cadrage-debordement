#!/usr/bin/env bash
# Exécute les suites d'un shard « Suites i/N » (liste produite par ci/shard-tests.cjs).
# Usage : bash ci/run-shard-suites.sh <liste> <titre> [suites-en-parallèle]
#   - suites-en-parallèle (défaut 1) : les suites sont quasi mono-cœur (cpu_pct ≈ 110-120 %)
#     et les 4 vCPU d'un runner GitHub sont 2 cœurs physiques (SMT) ; la CI en lance au plus 3
#     (ci/ci-jobs.cjs SHARD_PARALLEL). Suites « exclusives » (ci/shard-tests.cjs isExclusive :
#     longues ou machine virtuelle node:vm à délai interne) : tant qu'une d'elles tourne, au
#     plus EXCLUSIVE_CAP (2) suites au total, pour qu'elle garde un cœur physique entier.
#     La liste arrive par poids décroissant : les plus longues démarrent en premier.
#   - budget mémoire : chaque suite réserve sa mémoire de pointe mesurée (ci/suite-weights.json,
#     section « memory », défaut default_mb) et une suite ne démarre que si la somme des
#     réservations en cours reste sous budget_mb (12 Go sur un runner de 16 Go ; surcharge
#     possible par CD_SHARD_MEMORY_MB). Les suites lourdes (≈ 3,5-4 Go) ne tournent donc
#     jamais à quatre ensemble ; une suite plus grosse que le budget tourne seule. Si la
#     suivante ne tient pas, une plus légère de la liste passe devant.
#   - chaque suite garde son délai maximal propre (budgets ci-dessous, 100 % ; surcharge
#     possible par CD_SHARD_BUDGET_PCT, jamais transmise aux suites) ;
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
# Mode Monde uniquement : les suites à ancien mode de carrière (CD_MODES_HERITES) ne tournent jamais.
mapfile -t suites < <(node "$root/ci/legacy-modes.cjs" filter "$list")
if [[ "${#suites[@]}" -eq 0 ]]; then
  [[ -s "$list" ]] || { echo "Aucune suite dans $list" >&2; exit 1; }
  echo "Toutes les suites de $list sont exclues (ancien mode de carrière) : rien à exécuter." >&2
  exit 0
fi
# La liste filtrée devient la liste de référence (réservations mémoire, ordre d'exécution).
filtered_list="$(mktemp)"
printf '%s\n' "${suites[@]}" > "$filtered_list"
list="$filtered_list"
work="$(mktemp -d)"
mkdir -p "$work/logs" "$work/running"
: > "$work/results.md"
export CD_SHARD_WORK="$work"

# Délais : budgets ci-dessous tels quels (surcharge : CD_SHARD_BUDGET_PCT). Variable non
# exportée : les suites lancées (dont tests/ci-godot-runner.cjs) n'en héritent pas.
budget_pct="${CD_SHARD_BUDGET_PCT:-100}"
[[ "$budget_pct" =~ ^[1-9][0-9]{1,2}$ ]] || { echo "Pourcentage de délai invalide : $budget_pct" >&2; exit 2; }
unset CD_SHARD_BUDGET_PCT

budget() {
  # Budgets ciblés de réception cumulative, distincts des poids de planification.
  # Support a terminé en 883/941 s avant optimisation ; Nationale22 en 237,6 s.
  # Les autres réserves longues sont provisoires après les timeouts observés sur
  # 42891746395, sans retirer de contrôle.
  case "$1" in
    tests/world-worker-season.cjs) echo 1200s ;;
    tests/native-manager-career-worker.cjs) echo 900s ;;
    # Lot 03 (Monde) : saison de 46 semaines jouée jusqu'à la fenêtre de mobilité, puis saison suivante : 1250 s en local sous charge.
    tests/native-academy-integrated-long.cjs) echo 1800s ;;
    tests/native-delegate-transaction06.cjs|tests/native-contextual-integration.cjs) echo 600s ;;
    # Décisions natives et sauvegardes du direct en carrière Monde (une carrière pèse ~20 Mo de sauvegarde) : 314 s et 152 s en local sous charge.
    tests/native-decisions.cjs) echo 600s ;;
    tests/native-presentation-persistence.cjs) echo 420s ;;
    tests/native-nationale-reduced-bench.cjs|tests/godot-roster-foundation.cjs) echo 300s ;;
    # Lot 01 (Monde) : native-match-talks 779 s sous forte charge locale (deux carrières, plusieurs semaines).
    tests/native-match-talks.cjs) echo 900s ;;
    tests/native-club-support-season.cjs) echo 1200s ;;
    tests/native-club-world-worker.cjs) echo 900s ;;
    tests/native-club-strategy.cjs) echo 2400s ;; # Monde : saison de 46 semaines jouée jusqu'à next_season (1512 à 1581 s sous charge locale, 1062 à 1456 s en CI sur main ; le job Suites a 50 min)
    # Version Monde (migration du 13/11) : ~180-200 s en local, aussi sur main ; 180 s par défaut ne suffit plus.
    tests/performance-analysis.cjs) echo 600s ;;
    # Notes de match en carrière Monde (plusieurs semaines simulées, un test par processus).
    # Notes de match + XV type (journées et saison en carrière Monde) : ~15 min en CI.
    tests/match-notes.cjs) echo 1800s ;;
    # Homme du match par poste : carrière Monde hebdomadaire jusqu'à 150 matchs notés, 135 s en local sous charge.
    tests/homme-du-match-postes.cjs) echo 600s ;;
    # Fiche club : carrière Monde hebdomadaire, 3 journées (293 s en local sous forte charge).
    tests/fiche-club-monde.cjs) echo 600s ;;
    # Version CI : Nationale mondiale jusqu'à la semaine 14 (fenêtre de transferts de la semaine 13), ~390 s en local ;
    # la version complète (58 clubs, 3 saisons) vit dans club-intelligence-measure.yml (CD_STABILITY_FULL=1).
    # starting-salaries : quatre carrières réelles (commun et mondial, drapeau éteint et allumé), 176 s en local.
    tests/world-roster-stability.cjs) echo 900s ;;
    tests/starting-salaries.cjs) echo 600s ;;
    tests/native-press-season.cjs|tests/native-press-personalities-worker.cjs) echo 900s ;;
    # Mesurés aussi sur main (indépendants de la branche) : native-press-worker 220-240 s, potential-evolution-worker 166 s en CI / 196-255 s sous charge locale.
    tests/native-press-worker.cjs) echo 420s ;;
    tests/potential-evolution-worker.cjs) echo 360s ;;
    tests/deepen-staff-native.cjs) echo 1200s ;;
    # Réception locale complète 233 s ; conserve créations, Rooms et refus.
    tests/youth-scout-native.cjs) echo 600s ;;
    tests/youth-matches-worker.cjs) echo 420s ;;
    # Fixtures complètes PASS locales 142/126 s, sans refus précoce.
    tests/world-catalogue-dedup.cjs|tests/world-venue-media.cjs) echo 300s ;;
    tests/career-variation-worker.cjs|tests/management-day-worker.cjs) echo 600s ;;
    # PASS CI 42909005768 : 179,80/159,68 s, marge finie avant le cap 180.
    tests/world-worker.cjs) echo 300s ;;
    # Tests passés au Monde (lot 00) : carrière de 116 clubs, mesurés 200 à 300 s sous charge.
    tests/calendar-worker.cjs|tests/epcr-preparation-worker.cjs|tests/animation-live-cut.cjs) echo 420s ;;
    tests/deepen-analytics.cjs) echo 900s ;;
    # Lot 03 (Monde) : mesures locales sous charge (créneaux partagés) : lifecycle-native 214 s (8 tests, carrières de ~1 Go de tas),
    # match-direct 370 s (5 tests, 3 carrières), management-france-day-worker 200 s (avant-saison jouée jour par jour) ; assertions inchangées.
    tests/lifecycle-native.cjs|tests/management-france-day-worker.cjs) echo 420s ;;
    tests/match-direct.cjs) echo 600s ;;
    tests/progression-policies.cjs|tests/native-academy-groups.cjs|tests/profile-safety-worker.cjs) echo 420s ;;
    # JIFF en carrière Monde : une carrière world-champ jusqu'aux premières journées de Top 14, ~320 s en local sous charge.
    tests/jiff.cjs) echo 600s ;;
    # Tests migrés en carrière Monde : dépassent le délai par défaut (native-relationships 273 s en local).
    tests/performance-analysis.cjs|tests/native-relationships.cjs|tests/player-population-capacity.cjs) echo 600s ;;
    # Lot 01 (Monde) : mesures locales sous charge, 2 créneaux partagés, 86 à 413 s ; délais doublés, assertions inchangées.
    tests/native-club-meetings.cjs|tests/native-club-meetings-packs.cjs|tests/native-club-support.cjs|tests/native-club-support-medical.cjs|tests/native-club-support-effects.cjs|tests/native-playbook.cjs|tests/native-coach-notes06-pack.cjs|tests/native-manager-career-pack.cjs|tests/native-player-knowledge-worker.cjs|tests/native-position-integration.cjs|tests/native-position-editions.cjs) echo 600s ;;
    tests/native-club-support-training-forecast.cjs) echo 900s ;;
    # Passé au Monde (lot 00), 364 s en CI sous charge (run 43483, Suites 5/7) ; délai de 420 s dépassé sur deux runs de PR, 900 s, assertions inchangées.
    tests/integration-cloud-complete.cjs) echo 900s ;;
    # Presse/recrutement06 en carrière Monde, 172 s seul en local et 180 s dépassé en CI (Suites 5/7) ; 420 s, assertions inchangées.
    tests/native-press-followups06-worker.cjs) echo 420s ;;
    # Lot 01 (Monde), paquet 3 : deux carrières Monde jouées minute par minute (essai-visible, ~20 min sous charge locale) ; carnet : 358 s.
    tests/match-essai-visible.cjs|tests/native-coach-notes06-worker.cjs) echo 900s ;;
    tests/native-player-knowledge-capacity.cjs) echo 300s ;;
    # Lot 03 (Monde) : 3 tests de 40 à 76 s chacun (3 carrières), 190 s en tout en local sous charge ; délai élargi, assertions inchangées.
    tests/native-academy-appearance-bank.cjs) echo 420s ;;
    # Carrière Monde : création, un match, trois rechargements du profil (~340 s en local).
    tests/sauvegarde-idempotente.cjs) echo 900s ;;
    *) echo 180s ;;
  esac
}

run_one() {
  local test="$1" work="$CD_SHARD_WORK" name limit start code verdict log
  name="$(basename "$test")"
  log="$work/logs/$name.log"
  limit="$(budget "$test")"
  limit="$(( ${limit%s} * budget_pct / 100 ))s"
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

# Mémoire réservée (Mo) et exclusivité (1/0) par suite, dans l'ordre de la liste.
mapfile -t plan < <(node -e '
  const fs = require("node:fs");
  const { memoryOf, isExclusive } = require(process.argv[1] + "/ci/shard-tests.cjs");
  for (const f of fs.readFileSync(process.argv[2], "utf8").split("\n").filter(Boolean))
    console.log(memoryOf(f) + " " + (isExclusive(f) ? 1 : 0));
' "$root" "$list")
mems=(); excl=()
for line in "${plan[@]}"; do mems+=("${line% *}"); excl+=("${line#* }"); done
excl_cap="$(node -p 'require(process.argv[1]).EXCLUSIVE_CAP' "$root/ci/ci-jobs.cjs")"
mem_budget="${CD_SHARD_MEMORY_MB:-$(node -p 'require(process.argv[1]).memory?.budget_mb || 12288' "$root/ci/suite-weights.json")}"
[[ "$mem_budget" =~ ^[1-9][0-9]*$ && "$excl_cap" =~ ^[1-9]$ && "${#mems[@]}" -eq "${#suites[@]}" ]] ||
  { echo "Budget mémoire ou réservations invalides" >&2; exit 2; }

# Ordonnanceur : au plus $parallel suites, au plus $excl_cap dès qu'une exclusive tourne,
# somme des réservations ≤ $mem_budget.
declare -A pid_mem=() pid_excl=()
declare -a pending=("${!suites[@]}")
used=0
peak=0
while (( ${#pending[@]} > 0 || ${#pid_mem[@]} > 0 )); do
  while (( ${#pending[@]} > 0 && ${#pid_mem[@]} < parallel )); do
    pick=-1
    for k in "${!pending[@]}"; do
      i="${pending[$k]}"
      running_excl=0
      for p in "${!pid_excl[@]}"; do (( pid_excl[$p] )) && running_excl=1; done
      if (( excl[i] || running_excl )) && (( ${#pid_mem[@]} + 1 > excl_cap )); then continue; fi
      if (( used + mems[i] <= mem_budget || ${#pid_mem[@]} == 0 )); then pick=$k; break; fi
    done
    (( pick >= 0 )) || break
    i="${pending[$pick]}"
    unset 'pending[pick]'
    pending=("${pending[@]}")
    run_one "${suites[$i]}" &
    pid_mem[$!]="${mems[$i]}"
    pid_excl[$!]="${excl[$i]}"
    used=$(( used + mems[i] ))
    (( used > peak )) && peak=$used
  done
  (( ${#pid_mem[@]} > 0 )) || break
  done_pid=''
  wait -n -p done_pid "${!pid_mem[@]}" || true
  if [[ -n "$done_pid" && -n "${pid_mem[$done_pid]:-}" ]]; then
    used=$(( used - pid_mem[$done_pid] ))
    unset "pid_mem[$done_pid]" "pid_excl[$done_pid]"
  else
    # Sécurité : retirer toute suite déjà terminée.
    for p in "${!pid_mem[@]}"; do
      kill -0 "$p" 2>/dev/null || { used=$(( used - pid_mem[$p] )); unset "pid_mem[$p]" "pid_excl[$p]"; }
    done
  fi
done
executed="$(wc -l < "$work/results.md")"
failures="$(grep -c '| ECHEC' "$work/results.md" || true)"
total="$(find tests -maxdepth 1 -name '*.cjs' ! -name 'harness.cjs' | wc -l)"
{
  echo "### $title : $executed suites sur $total ($parallel en parallèle, $excl_cap si exclusive, mémoire réservée max $peak/$mem_budget Mo, délais $budget_pct %)"
  echo "| Suite | Résultat | Durée |"
  echo "| --- | --- | --- |"
  cat "$work/results.md"
  echo ""
  echo "**Échecs : $failures**"
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
rm -rf "$work"
[[ "$failures" -eq 0 && "$executed" -eq "${#suites[@]}" ]]
