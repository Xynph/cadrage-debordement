'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const [control, candidate, overridesPath] = process.argv.slice(2);
assert.ok(control && candidate && overridesPath, 'Usage : verifier.cjs témoin candidat dérogations');
const state = file => JSON.parse(JSON.parse(fs.readFileSync(file)).store['bdt-v1']);
const overrides = JSON.parse(fs.readFileSync(overridesPath, 'utf8'));
const before = state(control), after = state(candidate);
const source = fs.readFileSync(path.resolve(__dirname, '../../dist/rugby.js'), 'utf8');
const note = vm.runInNewContext(source.slice(0, source.indexOf('function slotEligible')) + '\nroleNote', {
  clamp: (value, min, max) => Math.min(max, Math.max(min, value)),
  focusedBonus: (player, skill) => player.dev?.specialization?.version === 1 ? player.dev.specialization.bonuses[skill] || 0 : 0,
});
const all = s => s.clubs.flatMap(club => club.players);
const descending = (a, b) => b - a;
const spread = values => {
  const sorted = values.slice().sort((a, b) => a - b);
  return sorted[Math.floor((sorted.length - 1) * .95)] - sorted[Math.floor((sorted.length - 1) * .1)];
};
const original = all(before), changed = all(after);
const topGlobal = changed.map(p => p.rating).sort(descending).slice(0, 10);
const topAtRole = changed.map(player => note(player)).sort(descending).slice(0, 10);
console.log(JSON.stringify({
  players: changed.length, topGlobal, topAtRole,
  spreadBefore: spread(original.map(p => p.rating)), spreadAfter: spread(changed.map(p => p.rating)),
}));
assert.ok(topGlobal.every(rating => rating > 90), 'Les dix meilleures notes globales dépassent 90');
assert.ok(topAtRole.every(rating => rating > 90), 'Les dix meilleures notes au poste dépassent 90');
assert.ok(spread(changed.map(p => p.rating)) > spread(original.map(p => p.rating)), 'L’écart P95–P10 s’élargit');
assert.equal(changed.length, original.length);
for (const [i, p] of original.entries()) {
  const q = changed[i];
  assert.equal(q.id, p.id);
  assert.equal(q.potential, p.potential);
  assert.deepEqual(q.worldProfile, p.worldProfile);
  assert.deepEqual(q.hiddenTraitsV2, p.hiddenTraitsV2);
  assert.equal(q.salary, p.salary);
  assert.equal(q.contractEnd, p.contractEnd);
  assert.equal(q.pos, p.pos);
  assert.deepEqual(Object.keys(q.attributesV2), Object.keys(p.attributesV2));
  assert.ok(Object.values(q.attributesV2).every(value => value >= 20 && value <= 97), q.id);
  if ((p.rating <= 73 || p.age < 23) && !Object.hasOwn(overrides, p.id)) assert.deepEqual(q, p);
  if (Object.hasOwn(overrides, p.id)) {
    for (const [axis, value] of Object.entries(overrides[p.id])) assert.equal(q.attributesV2[axis], value);
    for (const axis of Object.keys(p.attributesV2)) {
      if (!Object.hasOwn(overrides[p.id], axis)) assert.equal(q.attributesV2[axis], p.attributesV2[axis]);
    }
    assert.ok(q.rating > p.rating && note(q) > note(p));
    assert.equal(q.skills.goal, p.skills.goal);
  }
}
assert.deepEqual(after.market, before.market);
assert.deepEqual(after.economy, before.economy);
assert.deepEqual(after.development, before.development);
assert.deepEqual(after.aiRoster, before.aiRoster);
console.log('Invariants joueurs, contrats, viviers, spécialités et échelle vérifiés.');
