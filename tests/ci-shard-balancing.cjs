'use strict';
const assert = require('node:assert/strict');
const { allTestFiles, planShards, WEIGHTS_SECONDS } = require('../ci/shard-tests.cjs');
const { SHARD_COUNT } = require('../ci/ci-jobs.cjs');

const files = allTestFiles();
const groups = planShards(files);
assert.equal(groups.length, SHARD_COUNT, SHARD_COUNT + ' groupes attendus');
assert.ok(groups.every(group => group.length > 0), 'aucun groupe vide');
assert.deepEqual(groups.flat().sort(), files.slice().sort(), 'chaque suite exécutée exactement une fois');
assert.deepEqual(planShards(files.slice().reverse()), groups, 'répartition déterministe');

for (const [file, seconds] of Object.entries(WEIGHTS_SECONDS)) {
  assert.ok(files.includes(file), 'poids obsolète : ' + file);
  assert.ok(Number.isInteger(seconds) && seconds > 0, 'poids invalide : ' + file);
}
// Poids mesurés (ci/suite-weights.json) : les campagnes longues restent les plus lourdes.
for (const file of [
  'tests/native-academy-integrated-long.cjs',
  'tests/world-worker-season.cjs',
  'tests/deepen-staff-native.cjs',
  'tests/native-club-support-season.cjs'
]) {
  assert.ok(WEIGHTS_SECONDS[file] >= 300, 'campagne longue sous-pondérée : ' + file);
}
// Aucune suite ne dépasse à elle seule la charge visée d'un shard.
const heaviest = Math.max(...Object.values(WEIGHTS_SECONDS));
const total = files.reduce((sum, file) => sum + (WEIGHTS_SECONDS[file] || 1), 0);
assert.ok(heaviest <= total / SHARD_COUNT, 'suite plus longue qu\'un shard : ' + heaviest);
const projected = groups.map(group => group.reduce((sum, file) => sum + (WEIGHTS_SECONDS[file] || 1), 0));
assert.ok(Math.max(...projected) - Math.min(...projected) <= 5,
  'déséquilibre des poids prévisionnels : ' + projected.join('/'));
assert.throws(() => planShards([]), /absente/);
assert.throws(() => planShards(['tests/a.cjs', 'tests/a.cjs']), /dupliquée/);
assert.throws(() => planShards(['../secret.cjs']), /invalide/);
console.log('CI sharding : ' + files.length + ' suites distinctes en ' + SHARD_COUNT + ' groupes, poids ' + projected.join('/'));
