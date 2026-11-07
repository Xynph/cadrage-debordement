'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const candidate = JSON.parse(fs.readFileSync(path.join(root, 'data/scouting/review-v12/candidate.json'), 'utf8'));
const src = fs.readFileSync(path.join(root, 'dist/lnr-ratings-v12.js'), 'utf8');
const active = vm.runInNewContext(src + '\n;LNR_V12_PLAYER_DATA;');
const agingSrc = fs.readFileSync(path.join(root, 'dist/lnr-v11-aging.js'), 'utf8');
const aging = vm.runInNewContext(agingSrc + '\n;LNR_V11_AGE;');
const mean = arr => arr.reduce((sum, value) => sum + value, 0) / arr.length;
const byLeague = {top14: [], prod2: []};
for (const row of candidate.rows) {
  assert.ok(byLeague[row.league], 'Unknown division: ' + row.league);
  byLeague[row.league].push({row, tuple: active.players[row.playerId]});
}
function asPlayer(row, tuple) {
  return {
    id: row.playerId, gameplayPosition: row.role,
    attributesV2: Object.fromEntries(active.attributeKeys.map((key, i) => [key, tuple[3][i]])),
    hiddenTraitsV2: tuple[6], potential: tuple[2]
  };
}
test('1 592 identifiants et 57 312 notes actives, sans mutation du catalogue', () => {
  assert.equal(candidate.rows.length, 1592);
  assert.equal(new Set(candidate.rows.map(row => row.playerId)).size, 1592);
  assert.equal(Object.keys(active.players).length, 1592);
  assert.equal(active.attributeKeys.length, 36);
  assert.equal(new Set(active.attributeKeys).size, 36);
  assert.equal(active.skillKeys.length, 11);
  assert.deepEqual([...active.attributeKeys], [...candidate.attributeKeys]);
  assert.deepEqual([...active.skillKeys], [...candidate.skillKeys]);
  for (const row of candidate.rows) {
    const t = active.players[row.playerId];
    assert.ok(t, 'Profil absent: ' + row.playerId);
    assert.equal(t[3].length, 36, row.playerId);
    assert.equal(t[4].length, 11, row.playerId);
    assert.equal(t[5], row.role, row.playerId);
    assert.ok(Number.isFinite(t[0]) && t[0] >= 20 && t[0] <= 97, row.playerId);
    for (const score of t[3]) assert.ok(Number.isFinite(score) && score >= 20 && score <= 97, row.playerId);
    for (const skill of t[4]) assert.ok(Number.isFinite(skill) && skill >= 20 && skill <= 97, row.playerId);
    assert.equal(Object.keys(t[6]).length, 6, row.playerId);
  }
});
test('écart TOP14 / PRO D2 mesuré sur la BDD ACTIVE, par poste et globalement', () => {
  assert.equal(byLeague.top14.length, 805);
  assert.equal(byLeague.prod2.length, 787);
  const leagueMean = key => mean(byLeague[key].map(x => x.tuple[0]));
  const gap = leagueMean('top14') - leagueMean('prod2');
  assert.ok(gap >= 7 && gap <= 10, 'Écart global inattendu: ' + gap);
  const roles = [...new Set(candidate.rows.map(row => row.role))];
  assert.equal(roles.length, 11);
  for (const role of roles) {
    const top = byLeague.top14.filter(x => x.row.role === role).map(x => x.tuple[0]);
    const pro = byLeague.prod2.filter(x => x.row.role === role).map(x => x.tuple[0]);
    assert.ok(top.length > 0 && pro.length > 0, role);
    const delta = mean(top) - mean(pro);
    assert.ok(delta >= 6.5 && delta <= 10, role + ': ' + delta);
  }
  console.log('BDD ACTIVE: TOP14=' + leagueMean('top14').toFixed(2) +
    ' PRO D2=' + leagueMean('prod2').toFixed(2) + ' gap=' + gap.toFixed(2));
});
test('candidat V12 != notes actives : contrôler profondeur sans écrasement', () => {
  let different = 0, large = 0, flags = 0;
  for (const row of candidate.rows) {
    const t = active.players[row.playerId];
    const delta = t[0] - row.ratingV12;
    assert.ok(delta >= -5 && delta <= 4, row.playerId + ' variation hors échelle: ' + delta);
    if (delta !== 0) different++;
    if (Math.abs(delta) >= 4) large++;
    if (row.flags.includes('legacy-potential-scale-differs-from-role-ability')) flags++;
  }
  assert.ok(different > 1000);
  assert.equal(flags, 520);
  console.log('Différences candidat/actif: ' + different +
    ', écarts de 4+ points: ' + large + ', divergences échelle potentiel: ' + flags);
});
test('vieillissement V11 sur copie : physique après 35 ans et idempotence saison', () => {
  const row = candidate.rows.find(x => x.role === 'Centre' && x.league === 'top14');
  const t = active.players[row.playerId];
  const young = asPlayer(row, t);
  for (const key of Object.keys(young.attributesV2)) young.attributesV2[key] = 65;
  young.potential = 90;
  young.hiddenTraitsV2 = {...young.hiddenTraitsV2, professionalism: 65};
  const opts = {minutes: 1600, training: 1, injuryWeeks: 0, load: 0};
  const early = aging.step(young, {playerId: young.id, age: 20, season: 1}, opts);
  assert.ok(early.player.attributesV2.strength >= young.attributesV2.strength);
  assert.equal(early.player.potential, 90);
  const old = aging.step(young, {playerId: young.id, age: 38, season: 1}, opts);
  assert.ok(old.player.attributesV2.topSpeed < young.attributesV2.topSpeed);
  assert.ok(old.player.attributesV2.acceleration < young.attributesV2.acceleration);
  const physicalLoss = young.attributesV2.topSpeed - old.player.attributesV2.topSpeed;
  const mentalLoss = young.attributesV2.decisions - old.player.attributesV2.decisions;
  assert.ok(physicalLoss > mentalLoss, 'Le déclin physique doit être plus rapide');
  assert.equal(old.player.potential, 90);
  const same = aging.step(old.player, {...old.state, lastSeason: old.state.lastSeason}, opts);
  assert.equal(JSON.stringify(same.player), JSON.stringify(old.player), 'Même saison: aucun double vieillissement');
  assert.equal(JSON.stringify(young.attributesV2), JSON.stringify(Object.fromEntries(active.attributeKeys.map(k => [k, 65]))));
});
