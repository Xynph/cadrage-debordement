'use strict';
// Ouverture et création plus rapides (16/11/2026) : chaque raccourci rend exactement le même résultat.
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { test } = require('node:test');
const createJsonCopy = require('../native/engine/json-copy.cjs');
const { createV2 } = require('./helpers/senior-calibration-v2.cjs');

const viaJson = value => JSON.parse(JSON.stringify(value));

test('Copie JSON rapide : même texte que JSON.parse(JSON.stringify()), cas limites compris', () => {
  const copy = createJsonCopy();
  const foreign = vm.runInNewContext('({a:[1,{b:2}],d:new Date(0),m:new Map([[1,2]]),k:new (class K{constructor(){this.z=1}})(),n:Object.assign(Object.create(null),{q:1})})');
  const cases = [
    { a: 1, b: [1, undefined, () => 1, NaN, -0, Infinity], c: undefined, d: { e: null, 2: 3, 1: 4 }, f: new Date(0), g: new Map([[1, 2]]) },
    [1, { x: -0 }], { toJSON: () => 5 }, { ['__proto__']: 1 }, Object.create({ inherited: 1 }), { s: Symbol('x') }, foreign,
    JSON.parse('{"__proto__":{"x":1},"y":2}'), Object.assign([1, 2], { toJSON: () => 'x' }), new (class extends Array {})(3),
    { nested: { deep: [[{ v: 1.25 }], 'texte', true, null] } }, 5, 'texte', null, true,
  ];
  for (const value of cases) assert.equal(JSON.stringify(copy(value)), JSON.stringify(viaJson(value)));
  const source = { a: { b: [1] } }, result = copy(source);
  assert.notEqual(result.a, source.a, 'copie profonde');
  assert.notEqual(result.a.b, source.a.b, 'copie profonde');
  assert.equal(Object.getPrototypeOf(copy(foreign.a[1])), Object.prototype, 'objet de ce contexte, comme JSON.parse');
  assert.equal(Object.is(copy({ z: -0 }).z, 0), true);
  assert.throws(() => copy(undefined), SyntaxError);
  assert.throws(() => copy({ big: 1n }), TypeError);
});

test('Aperçu des effectifs (ratingsOnly) : mêmes notes que le barème complet, club par club', () => {
  const registry = require('../native/engine/world-registry.json');
  const { calibration } = createV2();
  const sources = new Map(registry.clubs.flatMap(club => club.players.map(player => [player.id, player])));
  let compared = 0;
  for (const club of registry.clubs) {
    const context = { clubId: club.id, leagueId: club.leagueId, registry };
    const full = viaJson(club.players), quick = viaJson(club.players);
    calibration.apply(full, sources, context);
    calibration.apply(quick, sources, context, { ratingsOnly: true });
    assert.deepEqual(quick.map(p => [p.id, p.rating]), full.map(p => [p.id, p.rating]), 'club ' + club.id);
    compared += full.length;
  }
  assert.ok(compared > 1000, 'effectifs comparés : ' + compared);
  // Un effectif avec un joueur de complément suit le barème complet (note au poste des coéquipiers recalés).
  const club = registry.clubs.find(c => c.players.length > 10), context = { clubId: club.id, leagueId: club.leagueId, registry };
  const depth = { id: 'depth-' + club.id + '-1-1', pos: club.players[0].pos, fam: club.players[0].fam, age: 25, rating: 60, dev: { potential: 62, seasonStart: 60 } };
  const full = [...viaJson(club.players), viaJson(depth)], quick = [...viaJson(club.players), viaJson(depth)];
  calibration.apply(full, sources, context);
  calibration.apply(quick, sources, context, { ratingsOnly: true });
  assert.deepEqual(quick, full);
});
