'use strict';
// Garde de répartition CI : données historiques réelles, pas un benchmark causal.
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS } = require('../ci/shard-tests.cjs');
const HISTORICAL = require('./fixtures/ci/p90-stress-41720921522.json');
const STRESS = 'tests/v63-2-stress-native.cjs';
// Runs SUCCESS chronologiques : 41708215803, 41709297149, 41715682628,
// 41716839980, 41720921522. Mesures arrondies à la seconde par le workflow.
const STRESS_SECONDS = Object.freeze([67, 62, 109, 82, 100]);
function percentile90(values) {
  assert.ok(Array.isArray(values) && values.length >= 2);
  assert.ok(values.every(n => Number.isFinite(n) && n >= 0));
  const sorted = values.slice().sort((a, b) => a - b);
  const position = (sorted.length - 1) * 0.9;
  const lower = Math.floor(position), fraction = position - lower;
  return sorted[lower] + (sorted[Math.ceil(position)] - sorted[lower]) * fraction;
}
assert.equal(percentile90(STRESS_SECONDS), 105.4);
assert.ok(WEIGHTS_SECONDS[STRESS] >= 140 && WEIGHTS_SECONDS[STRESS] <= 180,
  'Réserve V63.2 hors de la fenêtre éprouvée : reprofiler cinq CI avant modification');
// Trace partielle : les suites historiques non renseignées ont une charge nulle.
// Les nouvelles suites ne peuvent pas être projetées sur cette trace : leur charge
// inconnue modifierait les colocations sans contribuer aux sommes observées.
const LATEST_SECONDS = Object.freeze({
  [STRESS]: 100,
  'tests/opposition.cjs': 26,
  'tests/career-resilience.cjs': 13,
  'tests/economy-audit.cjs': 5,
  'tests/v63-1-long-career.cjs': 45,
  'tests/lnr05-fatigue-scenarios.cjs': 17,
  'tests/lnr-cross-season-recovery.cjs': 14,
  'tests/tactical-plans.cjs': 9,
  'tests/world-career.cjs': 38,
  'tests/lnr-career-long.cjs': 20,
  'tests/lnr05-multiseason-strategies.cjs': 20,
  'tests/saves.cjs': 10,
  'tests/lnr05-rest-policy-audit.cjs': 6,
  'tests/rugby.cjs': 36,
  'tests/lnr-multiclub-continuity.cjs': 34,
  'tests/lnr05-evidence-long.cjs': 25,
  'tests/lnr-save-resume-continuation.cjs': 16,
  'tests/ai-roster-cycle.cjs': 42,
  'tests/lnr05-rotation-audit.cjs': 19,
  'tests/manager-mobility.cjs': 14,
  'tests/lnr-save-integrity-guards.cjs': 8
});
// Cohorte exacte du dernier run SUCCESS ci-dessus, extraite de son arbre Git :
// git ls-tree -r --name-only 077c6c0d7f04b5656f6a8dbe8f5ddf9634486203 tests
// Même sélection que allTestFiles : .cjs directement dans tests/, hors harness.
assert.equal(HISTORICAL.runId, 41720921522);
assert.equal(HISTORICAL.headSha, '077c6c0d7f04b5656f6a8dbe8f5ddf9634486203');
const historicalFiles = HISTORICAL.files;
assert.equal(historicalFiles.length, 221, 'Cohorte historique complète');
assert.equal(new Set(historicalFiles).size, historicalFiles.length);
assert.deepEqual(historicalFiles.slice().sort(), historicalFiles);
for (const file of Object.keys(LATEST_SECONDS))
  assert.ok(historicalFiles.includes(file), 'Mesure hors cohorte : ' + file);
const oldWeights = { ...WEIGHTS_SECONDS, [STRESS]: 126 };
const oldPlan = planShards(historicalFiles, oldWeights);
const newPlan = planShards(historicalFiles);
assert.deepEqual(planShards(historicalFiles.slice().reverse()), newPlan,
  'Déterminisme historique');
// Contrat courant indépendant : aucune nouvelle suite ne sort du plan, même si
// sa durée ne figure pas dans la trace de novembre. Aucun gain CI actuel inféré.
const files = allTestFiles();
const currentPlan = planShards(files);
assert.deepEqual(currentPlan.flat().sort(), files.slice().sort(), 'Couverture exhaustive');
assert.equal(new Set(currentPlan.flat()).size, files.length, 'Doublon de suite');
assert.deepEqual(planShards(files.slice().reverse()), currentPlan, 'Déterminisme courant');
const sum = g => g.reduce((total, f) => total + (LATEST_SECONDS[f] || 0), 0);
const oldLoads = oldPlan.map(sum), newLoads = newPlan.map(sum);
const oldPeak = Math.max(...oldLoads), newPeak = Math.max(...newLoads);
assert.ok(newPeak < oldPeak,
  'La trace historique indépendante ne progresse pas : ' + oldPeak + ' -> ' + newPeak);
console.log('CI P90 stress PASS ; percentile 105,4 s ; rejeu partiel ' +
  oldPeak + ' -> ' + newPeak + ' s sur ' + historicalFiles.length +
  ' suites historiques ; couverture courante ' + files.length + ' suites');
