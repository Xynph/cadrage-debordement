'use strict';
// Rejeu historique de profil : comparaison contrefactuelle, PAS un benchmark causal.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { allTestFiles, planShards, planLoads } = require('../ci/shard-tests.cjs');
const { SHARD_COUNT } = require('../ci/ci-jobs.cjs');
// Décision du régime à cinq shards (poids figés au 11 novembre 2026), rejouée telle quelle.
const WEIGHTS_SECONDS = require('./fixtures/ci/weights-5-shards-20261111.json').weights;
const LONG = 'tests/lnr-career-long.cjs';
assert.equal(WEIGHTS_SECONDS[LONG], 55, 'Reserve de capacite suite longue');
const fixture = fs.readFileSync(path.resolve(__dirname, 'ci-shard-profiles.cjs'), 'utf8');
const marker = 'const PROFILES=';
const start = fixture.indexOf(marker);
assert.ok(start >= 0, 'Historique CI absent');
const terminator = /;\r?\n/.exec(fixture.slice(start));
const end = terminator ? start + terminator.index : -1;
assert.ok(end > start, 'Historique CI incomplet');
const profiles = JSON.parse(fixture.slice(start + marker.length, end));
assert.equal(profiles.length, 3, 'Trois traces completes attendues');
const historical = Object.keys(profiles[0]).sort();
assert.equal(historical.length, 220);
const previous = { ...WEIGHTS_SECONDS, [LONG]: 40 };
const oldPlan = planShards(historical, previous, 5);
const newPlan = planShards(historical, WEIGHTS_SECONDS, 5);
const peak = (groups, profile) => Math.max(...groups.map(g =>
  g.reduce((sum, file) => sum + (profile[file] || 0), 0)));
const before = profiles.map(p => peak(oldPlan, p));
const after = profiles.map(p => peak(newPlan, p));
assert.deepEqual(before, [151, 156, 165], 'Fixture avant changement inattendue');
assert.deepEqual(after, [148, 156, 161], 'Le nouvel equilibrage ne reproduit plus les trois traces');
assert.ok(after.every((x, i) => x <= before[i]), 'Regression historique');
const all = allTestFiles();
const groups = planShards(all);
assert.equal(groups.length, SHARD_COUNT);
assert.ok(groups.every(g => g.length > 0));
assert.deepEqual(groups.flat().sort(), all.slice().sort(), 'Couverture complete');
assert.equal(new Set(groups.flat()).size, all.length);
assert.deepEqual(planShards(all.slice().reverse()), groups, 'Determinisme');
const load = planLoads(groups);
assert.ok(Math.max(...load) - Math.min(...load) <= 5, 'Deséquilibre des poids prevus');
console.log('CI LONG CAREER BALANCE PASS: ' + before.join('/') +
  ' -> ' + after.join('/') + ' s (rejeu, pas gain causal) ; suites ' + all.length);
