'use strict';
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS } = require('../ci/shard-tests.cjs');

const files = allTestFiles();
const groups = planShards(files);
assert.equal(groups.length, 5, 'cinq groupes attendus');
assert.ok(groups.every(group => group.length > 0), 'aucun groupe vide');
assert.deepEqual(groups.flat().sort(), files.slice().sort(), 'chaque suite exécutée exactement une fois');
assert.deepEqual(planShards(files.slice().reverse()), groups, 'répartition déterministe');

for (const [file, seconds] of Object.entries(WEIGHTS_SECONDS)) {
  assert.ok(files.includes(file), 'poids obsolète : ' + file);
  assert.ok(Number.isInteger(seconds) && seconds > 0, 'poids invalide : ' + file);
}
for (const file of [
  'tests/lnr-multiclub-continuity.cjs',
  'tests/lnr05-evidence-long.cjs',
  'tests/lnr-career-long.cjs',
  'tests/lnr05-rotation-audit.cjs',
  'tests/lnr05-fatigue-scenarios.cjs'
]) {
  assert.ok(WEIGHTS_SECONDS[file] >= 35, 'suite lourde LNR sous-pondérée : ' + file);
}
const projected = groups.map(group => group.reduce((sum, file) => sum + (WEIGHTS_SECONDS[file] || 1), 0));
assert.ok(Math.max(...projected) - Math.min(...projected) <= 5,
  'déséquilibre des poids prévisionnels : ' + projected.join('/'));
assert.throws(() => planShards([]), /absente/);
assert.throws(() => planShards(['tests/a.cjs', 'tests/a.cjs']), /dupliquée/);
assert.throws(() => planShards(['../secret.cjs']), /invalide/);
console.log('CI sharding : ' + files.length + ' suites distinctes en cinq groupes, poids ' + projected.join('/'));
