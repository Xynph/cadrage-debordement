'use strict';
// Rejeu des durées réelles de huit runs GitHub verts (12 novembre 2026) sur la répartition
// courante (dix shards, poids mesurés) et sur l'ancienne (cinq shards, poids figés).
// Estimation contrefactuelle, PAS une mesure : chaque shard tourne sur sa propre machine.
const assert = require('node:assert/strict');
const { allTestFiles, planShards, planLoads, WEIGHTS_SECONDS, godotTestFiles, GODOT_WEIGHTS_SECONDS,
  GODOT_DEFAULT_WEIGHT, suitesForShard } = require('../ci/shard-tests.cjs');
const { SHARD_COUNT, GODOT_SHARD_COUNT } = require('../ci/ci-jobs.cjs');
const PROFILE = require('./fixtures/ci/profile-runs-20261112.json');
const LEGACY = require('./fixtures/ci/weights-5-shards-20261111.json');
const weights = require('../ci/suite-weights.json');

const files = allTestFiles();
assert.equal(PROFILE.runs.length, 8, 'Huit runs de référence');
assert.deepEqual(weights.js.runs, PROFILE.runs, 'Les poids viennent des runs rejoués');
for (const [file, seconds] of Object.entries(WEIGHTS_SECONDS))
  assert.ok(Number.isInteger(seconds) && seconds > 1, 'poids invalide : ' + file);
for (const [file, seconds] of Object.entries(GODOT_WEIGHTS_SECONDS))
  assert.ok(Number.isInteger(seconds) && seconds > 1, 'poids Godot invalide : ' + file);

const current = planShards(files);
const legacy = planShards(files, LEGACY.weights, LEGACY.shards);
assert.equal(current.length, SHARD_COUNT);
assert.equal(legacy.length, 5);
for (const plan of [current, legacy]) {
  assert.deepEqual(plan.flat().sort(), files, 'Chaque suite exactement une fois');
  assert.ok(plan.every(group => group.length > 0), 'Aucun shard vide');
}
assert.deepEqual(planShards(files.slice().reverse()), current, 'Déterminisme');

const peak = (plan, run) => Math.max(...plan.map(group =>
  group.reduce((sum, file) => sum + (PROFILE.suites[file]?.[run] ?? 0), 0)));
const before = [], after = [];
for (let run = 0; run < PROFILE.runs.length; run++) {
  before.push(peak(legacy, run));
  after.push(peak(current, run));
  assert.ok(after[run] < before[run] * 0.6, 'Run ' + PROFILE.runs[run] + ' : ' + before[run] + ' -> ' + after[run] + ' s');
  assert.ok(after[run] <= 26 * 60, 'Pic rejoué trop long : ' + after[run] + ' s');
}
const median = values => { const s = values.slice().sort((a, b) => a - b); return (s[3] + s[4]) / 2; };
assert.ok(median(after) <= 22 * 60, 'Pic médian rejoué au-delà de 22 min : ' + median(after) + ' s');

// Planification projetée (poids + 15 %) : équilibre serré, la suite la plus longue tient seule.
const loads = planLoads(current);
assert.ok(Math.max(...loads) - Math.min(...loads) <= 5, 'Déséquilibre : ' + loads.join('/'));
assert.ok(Math.max(...Object.values(WEIGHTS_SECONDS)) <= Math.max(...loads));

// Jobs Godot : suites qui lisent CD_GODOT_EXE ou CD_GODOT_EXECUTABLE, réparties sans perte.
const godot = godotTestFiles(files);
assert.ok(godot.length >= 100, 'Suites Godot découvertes : ' + godot.length);
for (const name of ['godot-engine', 'godot-match-rendu', 'deepen-match', 'native-academy-ui'])
  assert.ok(godot.includes('tests/' + name + '.cjs'), name);
for (const name of ['godot-assets', 'godot-common-rosters', 'saves'])
  assert.ok(!godot.includes('tests/' + name + '.cjs'), name + ' est du JavaScript pur');
const godotPlan = Array.from({ length: GODOT_SHARD_COUNT }, (_, i) => suitesForShard(i + 1, 'godot'));
assert.deepEqual(godotPlan.flat().sort(), godot);
assert.deepEqual(godotPlan, planShards(godot, GODOT_WEIGHTS_SECONDS, GODOT_SHARD_COUNT, GODOT_DEFAULT_WEIGHT));

console.log('ci-shard-replay PASS : pic rejoué 5 shards ' + before.map(s => Math.round(s / 60)).join('/') +
  ' min -> 10 shards ' + after.map(s => Math.round(s / 60)).join('/') + ' min (estimation, pas une mesure) ; ' +
  files.length + ' suites, ' + godot.length + ' suites Godot en ' + GODOT_SHARD_COUNT + ' jobs');
