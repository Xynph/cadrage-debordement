'use strict';
// Garde de répartition CI : données historiques réelles, pas un benchmark causal.
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS } = require('../ci/shard-tests.cjs');
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
// Les suites non renseignées dans la fixture ont une charge nulle : comparer
// deux répartitions identiques sur la même trace, sans inventer de durées.
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
const files = allTestFiles();
for (const file of Object.keys(LATEST_SECONDS))
  assert.ok(files.includes(file), 'Fixture obsolète : ' + file);
const oldWeights = { ...WEIGHTS_SECONDS, [STRESS]: 126 };
const oldPlan = planShards(files, oldWeights);
const newPlan = planShards(files);
assert.deepEqual(newPlan.flat().sort(), files.slice().sort(), 'Couverture exhaustive');
assert.equal(new Set(newPlan.flat()).size, files.length, 'Doublon de suite');
assert.deepEqual(planShards(files.slice().reverse()), newPlan, 'Déterminisme');
const sum = g => g.reduce((total, f) => total + (LATEST_SECONDS[f] || 0), 0);
const oldLoads = oldPlan.map(sum), newLoads = newPlan.map(sum);
const oldPeak = Math.max(...oldLoads), newPeak = Math.max(...newLoads);
assert.ok(newPeak < oldPeak,
  'La trace indépendante ne progresse pas : ' + oldPeak + ' -> ' + newPeak);
console.log('CI P90 stress PASS ; percentile 105,4 s ; rejeu partiel ' +
  oldPeak + ' -> ' + newPeak + ' s ; couverture ' + files.length + ' suites');
