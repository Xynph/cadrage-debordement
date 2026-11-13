'use strict';
// Promotions au mérite des clubs de l'ordinateur (décision de Léo du 12/11/2026).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./france-harness.cjs');

function setup() {
  const h = context(437493);
  h.run("start(0, 'france');");
  return h;
}

test('Un espoir au niveau du moins bon pro de son poste, ou un crack, est promu ; les autres restent au centre', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => {
    const c = S.clubs.find(x => x.id !== S.club && aiRosterAcademy(x)?.players.length >= 3);
    const a = aiRosterAcademy(c);
    // On libère deux places pro et on prépare trois espoirs.
    c.players.sort((x, y) => x.rating - y.rating); c.players.splice(0, 2);
    const [ready, crack, plain] = a.players;
    const weakest = Math.min(...c.players.filter(q => q.fam === ready.fam).map(q => q.rating));
    for (const p of [ready, crack, plain]) { p.age = 19; p.injury = 0; p.salary = 2000; }
    ready.rating = weakest;
    crack.rating = 40; crack.dev.potential = 92;
    plain.rating = 30; plain.dev.potential = 70;
    for (const p of a.players.slice(3)) { p.age = 17; }
    const count = aiRosterMeritPromotions(c);
    const pro = new Set(c.players.map(p => p.id));
    return JSON.stringify({ count, ready: pro.has(ready.id), crack: pro.has(crack.id), plain: pro.has(plain.id),
      academy: a.players.some(p => p.id === ready.id), contract: c.players.find(p => p.id === ready.id)?.contractEnd === S.season + 2 });
  })()`));
  assert.equal(r.ready, true);
  assert.equal(r.crack, true);
  assert.equal(r.plain, false);
  assert.equal(r.academy, false);
  assert.equal(r.contract, true);
  assert.equal(r.count, 2);
});

test('Sans place pro, aucune promotion ; ancienne politique de population inchangée', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => {
    const c = S.clubs.find(x => x.id !== S.club && aiRosterAcademy(x)?.players.length >= 1);
    const a = aiRosterAcademy(c);
    for (const p of a.players) { p.age = 20; p.rating = 99; }
    while (professionalPlaces(c) > 0) c.players.push({ ...c.players[0], id: c.players[0].id + '-x' + c.players.length });
    const full = aiRosterMeritPromotions(c);
    const saved = S.aiRosterVersion; S.aiRosterVersion = 1;
    const legacy = aiRosterMeritPromotions(c);
    S.aiRosterVersion = saved;
    return JSON.stringify({ full, legacy });
  })()`));
  assert.equal(r.full, 0);
  assert.equal(r.legacy, 0);
});
