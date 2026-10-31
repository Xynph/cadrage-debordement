'use strict';
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS } = require('../ci/shard-tests.cjs');
const all = allTestFiles();
assert.ok(all.length >= 81, 'Toutes les suites doivent être découvertes');
assert.ok(all.includes('tests/saves.cjs'));
const groups = planShards(all);
assert.equal(groups.length, 5);
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
const snapshot = Object.keys(WEIGHTS_SECONDS);
for (let i = 0; i < 58; i++) snapshot.push('tests/synthetic-' + i + '.cjs');
const scores = planShards(snapshot).map(group =>
  group.reduce((sum, f) => sum + (WEIGHTS_SECONDS[f] || 1), 0));
assert.ok(Math.max(...scores) - Math.min(...scores) <= 3,
  'Mauvais équilibre historique : ' + scores.join('/'));
console.log('CI-sharding OK : ' + all.length + ' suites, sans exclusion');
