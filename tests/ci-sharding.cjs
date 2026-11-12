'use strict';
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS, shardCount } = require('../ci/shard-tests.cjs');
const { SHARD_COUNT } = require('../ci/ci-jobs.cjs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const all = allTestFiles();
assert.ok(all.length >= 81, 'Toutes les suites doivent être découvertes');
assert.ok(all.includes('tests/saves.cjs'));
const groups = planShards(all);
assert.equal(groups.length, SHARD_COUNT);
assert.equal(SHARD_COUNT, 5);
for (const group of groups) assert.ok(group.length, 'Groupe vide');
assert.equal(new Set(groups.flat()).size, all.length, 'Suite dupliquée');
assert.deepEqual(groups.flat().sort(), all.slice().sort(), 'Suite omise');
assert.deepEqual(planShards(all.slice().reverse()), groups, 'Non déterministe');
assert.ok(groups.some(g => g.includes('tests/saves.cjs')));
for (const f of ['world-career', 'ai-roster-cycle', 'rugby'])
  assert.ok(groups.some(g => g.includes('tests/' + f + '.cjs')), f);
const future = 'tests/future-unknown.cjs';
assert.deepEqual(planShards([...all, future]).flat().sort(),
  [...all, future].sort(), 'Une nouvelle suite doit être incluse une seule fois');
assert.throws(() => planShards([...all, all[0]]), /dupliquée/);
assert.throws(() => planShards([]), /absente/);
assert.throws(() => planShards(['tests/harness.cjs']), /invalide/);
assert.throws(() => planShards(['tests/x.cjs'], {'tests/x.cjs': -1}), /invalide/);
// Nombre de shards paramétrable et validé.
for (const count of [1, 3, 5, 10, 16]) {
  const plan = planShards(all, WEIGHTS_SECONDS, count);
  assert.equal(plan.length, count);
  assert.deepEqual(plan.flat().sort(), all.slice().sort(), 'Couverture à ' + count + ' shards');
}
for (const bad of [0, -1, 1.5, 65, '3a', ''])
  assert.throws(() => shardCount(bad), /Nombre de shards invalide/, String(bad));
// Moins de suites que de shards (couvertures ciblées) : shards finaux vides, aucune perte.
assert.deepEqual(planShards(['tests/a.cjs', 'tests/b.cjs'], {}, 4).map(g => g.length).sort(), [0, 0, 1, 1]);
// Ligne de commande : usage, bornes et couvertures.
const cli = (...args) => spawnSync(process.execPath, [path.resolve(__dirname, '../ci/shard-tests.cjs'), ...args], { encoding: 'utf8' });
const listed = [];
for (let shard = 1; shard <= SHARD_COUNT; shard++) {
  const run = cli(String(shard), 'full', String(SHARD_COUNT));
  assert.equal(run.status, 0, run.stderr);
  listed.push(...run.stdout.trim().split('\n'));
}
assert.deepEqual(listed.sort(), all.slice().sort(), 'Les cinq shards CLI couvrent toutes les suites');
assert.equal(cli('6').status, 1);
assert.match(cli('6').stderr, /hors de 1\.\.5/);
for (const args of [[], ['0'], ['x'], ['1', 'full', '0'], ['1', 'full', '2', 'extra']]) {
  const run = cli(...args);
  assert.equal(run.status, 2, args.join(' '));
  assert.match(run.stderr, /Usage : node ci\/shard-tests\.cjs <shard>/);
}
assert.equal(cli('1', 'inconnue').status, 1);
assert.equal(cli('9', 'native-art', '10').stdout, '', 'Shard vide autorisé en couverture ciblée');
const snapshot = Object.keys(WEIGHTS_SECONDS);
for (let i = 0; i < 58; i++) snapshot.push('tests/synthetic-' + i + '.cjs');
const scores = planShards(snapshot).map(group =>
  group.reduce((sum, f) => sum + (WEIGHTS_SECONDS[f] || 1), 0));
assert.ok(Math.max(...scores) - Math.min(...scores) <= 3,
  'Mauvais équilibre historique : ' + scores.join('/'));
console.log('CI-sharding OK : ' + all.length + ' suites, sans exclusion');
