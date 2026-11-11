'use strict';
// Répartition complète et déterministe : toutes les suites sont conservées.
// Pondérations = max des durées de trois runs SUCCESS (PR #41708215803,
// main #41709297149, PR #41715682628) + 15 % de marge arrondie.
// Le pic simulé ne constitue pas une mesure de gain réel ; reprofiler régulièrement.
// V63.2 : réserve anti-colocation (poids de planification, PAS sa durée mesurée).
// Cinq runs SUCCESS : 62/67/82/100/109 s ; P90 interpolé 105,4 s.
// Réserve 150 pour éviter de grouper cette suite variable avec d'autres longues.
// Rejeu des trois anciens profils : aucun pic supérieur au plan précédent.
const fs = require('node:fs');
const path = require('node:path');
const HISTORICAL_WEIGHTS_SECONDS = Object.freeze({
  // Rendez-vous obligatoires : PASS locaux du 10 novembre 2026 (Node 24),
  // parcours complets et recettes de compatibilité, maximum + 15 % arrondi.
  // Ce sont des poids de planification, pas des durées GitHub mesurées.
  'tests/deepen-analytics.cjs': 25,
  'tests/deepen-market-worker.cjs': 23,
  'tests/deepen-youth-worker.cjs': 35,
  'tests/france-cover.cjs': 11,
  'tests/interclub-market.cjs': 21,
  'tests/lifecycle-native.cjs': 55,
  'tests/native-academy-integrated-long.cjs': 394,
  'tests/native-academy-worker.cjs': 56,
  'tests/native-club-strategy.cjs': 87,
  'tests/native-club-support-effects.cjs': 15,
  'tests/native-club-support-medical.cjs': 50,
  'tests/native-club-support-training-forecast.cjs': 33,
  'tests/native-club-support.cjs': 50,
  'tests/native-coach-notes06-worker.cjs': 18,
  'tests/native-contextual-integration.cjs': 153,
  'tests/native-fiction-sheet.cjs': 80,
  'tests/native-manager-career-worker.cjs': 199,
  'tests/native-match-talks.cjs': 57,
  'tests/native-press-followups06-worker.cjs': 13,
  'tests/native-press-worker.cjs': 19,
  'tests/native-relationships.cjs': 49,
  'tests/regen-scouting.cjs': 35,
  'tests/world-champ-worker.cjs': 53,
  'tests/world-worker-season.cjs': 375,
  // Staff et rendez-vous combinés : suites complètes PASS locales Node 24,
  // le 10 novembre 2026. Maximum mesuré + 15 %, pas des durées GitHub.
  'tests/native-staff-completion.cjs': 34,
  'tests/native-staff-completion-season.cjs': 5,
  'tests/staff-completion.cjs': 2,
  'tests/regen-portrait-persistence.cjs': 12,
  'tests/staff-career.cjs': 2,
  'tests/native-club-support-season.cjs': 197,
  // Dernière réception PC527 : Node22.23.4,166,988s/15,264s,+15%.
  'tests/deepen-staff-native.cjs': 193,
  'tests/world-worker-atomic.cjs': 18,
  // Profils #409 et #412 du 9 novembre 2026. Maximum mesuré et marge de 15 %.
  'tests/v63-2-stress-native.cjs': 150,
  'tests/v63-1-long-career.cjs': 91,
  'tests/ai-roster-cycle.cjs': 87,
  'tests/world-career.cjs': 74,
  'tests/rugby.cjs': 59,
  'tests/lnr-multiclub-continuity.cjs': 55,
  'tests/lnr-career-long.cjs': 55,
  // Population v2 : mesures Node 22 48 / 29,6 / 12,2 s.
  'tests/player-population-worker.cjs': 15,
  // Suites d'au moins 35 s sur #422, #423 et les cinq shards verts de #424.
  // Maximum + 15 % (runs 42606201094, 42641635525, 42669973393 tentative 1).
  'tests/france-career.cjs': 46,
  'tests/france-long-career-late.cjs': 94,
  'tests/france-long-career.cjs': 90,
  'tests/godot-common-rosters.cjs': 51,
  'tests/godot-roster-foundation.cjs': 50,
  'tests/native-academy-loan-capacity.cjs': 59,
  'tests/native-academy-network-validation.cjs': 73,
  'tests/native-club-world-worker.cjs': 88,
  'tests/native-delegate-transaction06.cjs': 187,
  'tests/native-manager-career-reverse.cjs': 62,
  'tests/native-press-personalities-worker.cjs': 95,
  'tests/native-press-season.cjs': 64,
  'tests/player-population-capacity.cjs': 55,
  'tests/player-population-seasons.cjs': 83,
  'tests/rugby-real-long-career-qa.cjs': 99,
  'tests/world-worker.cjs': 43,
  'tests/youth-scout-native.cjs': 65,
  'tests/lnr05-rotation-audit.cjs': 40,
  'tests/lnr05-fatigue-scenarios.cjs': 38,
  'tests/lnr05-multiseason-strategies.cjs': 37,
  'tests/lnr05-evidence-long.cjs': 35,
  'tests/opposition.cjs': 34,
  'tests/manager-mobility.cjs': 32,
  'tests/lnr-cross-season-recovery.cjs': 26,
  'tests/lnr-save-resume-continuation.cjs': 25,
  'tests/saves.cjs': 22,
  'tests/tactical-plans.cjs': 19,
  'tests/lnr-save-integrity-guards.cjs': 17,
  'tests/career-resilience.cjs': 14,
  'tests/lnr05-rest-policy-audit.cjs': 11,
  'tests/economy-audit.cjs': 6,
  'tests/lnr-save-import-rollback-stress.cjs': 5,
  'tests/v28-collective-preparation.cjs': 5,
  'tests/v29-focused-development.cjs': 5
});
// Réception cumulative du 10 novembre : réserves de planification provisoires.
// Les anciens profils n'incluaient pas simultanément observation, attributs,
// nouvelles populations et rendez-vous. Ces réserves NE sont PAS des mesures
// GitHub : elles équilibrent les campagnes en attendant le prochain profil CI.
// Support : campagne complète locale 883/941 s avant optimisation pure ;
// Nationale22 : 237,6 s ; les budgets d'arrêt restent distincts dans tests.yml.
const WEIGHTS_SECONDS = Object.freeze({ ...HISTORICAL_WEIGHTS_SECONDS,
  'tests/native-club-support-season.cjs': 750,
  'tests/world-worker-season.cjs': 650,
  'tests/native-manager-career-worker.cjs': 450,
  'tests/native-manager-career-reverse.cjs': 400,
  'tests/native-delegate-transaction06.cjs': 450,
  'tests/native-contextual-integration.cjs': 350,
  'tests/native-club-world-worker.cjs': 450,
  'tests/native-club-strategy.cjs': 300,
  'tests/native-press-season.cjs': 450,
  'tests/native-press-personalities-worker.cjs': 450,
  'tests/deepen-staff-native.cjs': 600,
  'tests/custom-competition-worker.cjs': 450,
  'tests/career-variation-worker.cjs': 300,
  'tests/native-academy-integrated-long.cjs': 1000,
  'tests/native-nationale-reduced-bench.cjs': 250,
  'tests/native-player-knowledge-worker.cjs': 150,
  'tests/native-academy-groups.cjs': 160,
  'tests/progression-policies.cjs': 280,
  'tests/profile-safety-worker.cjs': 160,
  'tests/integration-cloud-complete.cjs': 150,
  'tests/native-nation-meetings.cjs': 125,
  'tests/native-club-meetings.cjs': 190,
  'tests/native-academy-loan-capacity.cjs': 180,
  'tests/native-professional-depth.cjs': 80,
  'tests/native-player-attributes.cjs': 80,
  'tests/potential-evolution-worker.cjs': 80,
  'tests/management-day-worker.cjs': 350,
  'tests/management-france-day-worker.cjs': 60,
  'tests/native-match-talks.cjs': 210,
  'tests/godot-roster-foundation.cjs': 200,
  // Suites PASS du run42909005768 (HEAD464021b), wall mesuré +15%.
  // Une mesure individuelle ne déclare pas vert le run global rouge.
  // V63.1 garde sa réserve historique91 : arrondir79,57s+15% à92
  // dégrade le rejeu des trois traces; ce poids ne fixe pas son délai maximal.
  'tests/deepen-analytics.cjs': 82,
  'tests/deepen-staff-native.cjs': 624,
  'tests/deepen-youth-worker.cjs': 85,
  'tests/epcr-preparation-worker.cjs': 103,
  'tests/france-career.cjs': 207,
  'tests/france-saves.cjs': 97,
  'tests/godot-common-rosters.cjs': 80,
  'tests/godot-engine.cjs': 91,
  'tests/lifecycle-native.cjs': 109,
  'tests/native-academy-appearance-bank.cjs': 100,
  'tests/native-academy-integrated-long.cjs': 1263,
  'tests/native-academy-network-validation.cjs': 80,
  'tests/native-club-support-medical.cjs': 119,
  'tests/native-fiction-sheet.cjs': 100,
  'tests/native-manager-career-reverse.cjs': 515,
  'tests/native-manager-career-worker.cjs': 480,
  'tests/native-press-personalities-worker.cjs': 516,
  'tests/native-staff-completion.cjs': 77,
  'tests/player-population-capacity.cjs': 142,
  'tests/regen-scouting.cjs': 98,
  'tests/rugby-real-long-career-qa.cjs': 101,
  'tests/world-champ-worker.cjs': 125,
  'tests/world-save-runtime.cjs': 92,
  'tests/world-worker-season.cjs': 878,
  'tests/world-worker.cjs': 184,
  // Réserve : PASS local complet236,649s sousNode22, y compris fixture legacy.
  'tests/youth-scout-native.cjs': 300,
  // PASS locaux Node22, deux suites au plus en parallèle : temps reçus+15%.
  // Catalogue: wall ; venue: somme des deux cas (détail dans la réception JSON).
  'tests/world-catalogue-dedup.cjs': 164,
  'tests/world-venue-media.cjs': 145
});
const lexical = (a, b) => a < b ? -1 : a > b ? 1 : 0;
function allTestFiles() {
  return fs.readdirSync(path.resolve(__dirname, '..', 'tests'), { withFileTypes: true })
    .filter(e => e.isFile() && e.name.endsWith('.cjs') && e.name !== 'harness.cjs')
    .map(e => 'tests/' + e.name).sort(lexical);
}
function planShards(files, weights = WEIGHTS_SECONDS) {
  if (!Array.isArray(files) || files.length === 0) throw Error('Liste des suites absente');
  if (files.some(f => typeof f !== 'string' ||
      !/^tests\/[A-Za-z0-9._-]+\.cjs$/.test(f) || f === 'tests/harness.cjs'))
    throw Error('Chemin de suite invalide');
  if (new Set(files).size !== files.length) throw Error('Suite dupliquée');
  const weight = f => {
    const value = Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : 1;
    if (!Number.isFinite(value) || value < 1) throw Error('Poids invalide : ' + f);
    return value;
  };
  const ordered = files.slice().sort((a, b) => weight(b) - weight(a) || lexical(a, b));
  const shards = Array.from({ length: 5 }, () => ({ weight: 0, files: [] }));
  for (const file of ordered) {
    let target = 0;
    for (let i = 1; i < shards.length; i++) {
      if (shards[i].weight < shards[target].weight ||
          (shards[i].weight === shards[target].weight &&
           shards[i].files.length < shards[target].files.length)) target = i;
    }
    shards[target].files.push(file);
    shards[target].weight += weight(file);
  }
  return shards.map(g => g.files.sort(lexical));
}
if (require.main === module) {
  const [, , shard, coverage = 'full'] = process.argv;
  if (process.argv.length > 4 || !/^[1-5]$/.test(shard)) {
    console.error('Usage : node ci/shard-tests.cjs <1|2|3|4|5> [full|web|native-art]');
    process.exitCode = 2;
  } else {
    try {
      const { suitesForCoverage } = require('./test-coverage.cjs');
      const suites = suitesForCoverage(coverage, allTestFiles());
      if (suites.length < 5) throw Error('Il faut au moins une suite par shard');
      for (const file of planShards(suites)[Number(shard) - 1])
        console.log(file);
    } catch (error) {
      console.error(error.message);
      process.exitCode = 1;
    }
  }
}
module.exports = { allTestFiles, planShards, WEIGHTS_SECONDS };
