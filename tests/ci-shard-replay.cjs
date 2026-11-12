'use strict';
// Rejeu des durées réelles de huit runs GitHub verts (12 novembre 2026) : répartition
// courante (cinq shards × quatre suites, budget mémoire) contre dix shards × deux suites.
// Estimation contrefactuelle, PAS une mesure : chaque shard tourne sur sa propre machine.
const assert = require('node:assert/strict');
const { allTestFiles, planShards, planLoads, WEIGHTS_SECONDS, godotTestFiles, GODOT_WEIGHTS_SECONDS,
  GODOT_DEFAULT_WEIGHT, suitesForShard, simulateShard, MEMORY } = require('../ci/shard-tests.cjs');
const { SHARD_COUNT, SHARD_PARALLEL, GODOT_SHARD_COUNT } = require('../ci/ci-jobs.cjs');
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
const tenByTwo = planShards(files, WEIGHTS_SECONDS, 10);
assert.equal(current.length, SHARD_COUNT);
assert.equal(SHARD_PARALLEL, 4);
assert.equal(legacy.length, 5);
for (const plan of [current, legacy, tenByTwo]) {
  assert.deepEqual(plan.flat().sort(), files, 'Chaque suite exactement une fois');
  assert.ok(plan.every(group => group.length > 0), 'Aucun shard vide');
}
assert.deepEqual(planShards(files.slice().reverse()), current, 'Déterminisme');

// Rejeu avec l'ordonnanceur de ci/run-shard-suites.sh (simulateShard) : avant = 10 runners
// × 2 suites (configuration du 12/11), après = 5 runners × 4 suites sous budget mémoire,
// durées majorées de 15 % (contention : 4 suites à ~115 % de CPU sur 4 cœurs). Les suites
// absentes des runs de référence prennent leur poids. Estimation, pas une mesure.
const CONTENTION = 1.15;
const before = [], after = [];
for (let run = 0; run < PROFILE.runs.length; run++) {
  const duration = file => PROFILE.suites[file]?.[run] ?? (WEIGHTS_SECONDS[file] || 1) / 1.15;
  before.push(Math.max(...tenByTwo.map(group => simulateShard(group, duration, 2).wall)));
  const shards = current.map(group => simulateShard(group, file => duration(file) * CONTENTION, SHARD_PARALLEL));
  after.push(Math.max(...shards.map(s => s.wall)));
  for (const s of shards) assert.ok(s.peakMb <= MEMORY.budgetMb, 'Budget mémoire dépassé : ' + s.peakMb);
  assert.ok(after[run] <= before[run] * 1.25, 'Run ' + PROFILE.runs[run] + ' : ' + before[run] + ' -> ' + after[run] + ' s');
  assert.ok(after[run] <= 26 * 60, 'Pic rejoué trop long : ' + after[run] + ' s');
}
const median = values => { const s = values.slice().sort((a, b) => a - b); return (s[3] + s[4]) / 2; };
assert.ok(median(after) <= 22 * 60, 'Pic médian rejoué au-delà de 22 min : ' + median(after) + ' s');
// La plus longue suite fixe le plancher : aucun shard ne doit la dépasser de plus de 15 %.
const longest = Math.max(...Object.values(WEIGHTS_SECONDS));
assert.ok(Math.max(...current.map(g => simulateShard(g, f => (WEIGHTS_SECONDS[f] || 1) * CONTENTION, SHARD_PARALLEL).wall)) <= longest * CONTENTION + 1);
// Ordonnanceur : budget respecté, suite plus grosse que le budget seule, aucune perte.
{
  const mem = { 'tests/a.cjs': 5000, 'tests/b.cjs': 5000, 'tests/c.cjs': 5000, 'tests/d.cjs': 20000 };
  const r = simulateShard(Object.keys(mem), () => 10, 4, { memory: f => mem[f], budget: 12000, weights: {} });
  assert.equal(r.wall, 30, 'a+b, puis c, puis d seule');
  assert.equal(r.peakMb, 20000);
  assert.equal(simulateShard(['tests/x.cjs', 'tests/y.cjs'], () => 5, 4, { memory: () => 1, budget: 10, weights: {} }).wall, 5);
}

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

console.log('ci-shard-replay PASS : pic rejoué 10×2 ' + before.map(s => Math.round(s / 60)).join('/') +
  ' min -> 5×4 ' + after.map(s => Math.round(s / 60)).join('/') + ' min (estimation, pas une mesure) ; ' +
  files.length + ' suites, ' + godot.length + ' suites Godot en ' + GODOT_SHARD_COUNT + ' jobs');
