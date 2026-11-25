'use strict';
// Promotions au mérite des clubs de l'ordinateur (décision de Léo du 12/11/2026).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

function setup() {
  const h = context(437493);
  return h;
}

test('Un espoir au niveau du moins bon pro de son poste, ou un crack, est promu ; les autres restent au centre', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => {
    const c = S.clubs.find(x => x.id !== S.club && aiRosterAcademy(x)?.players.length >= 3);
    const a = aiRosterAcademy(c);
    // On libère deux places pro et on prépare trois espoirs.
    // Les deux places libérées rendent au moins deux salaires du plus bas niveau du club : les espoirs
    // promus le sont à ce salaire, qui tient sous la limite de masse (budget réaliste par défaut ou non).
    const floor = Math.min(...c.players.map(q => q.salary));
    c.players.sort((x, y) => x.rating - y.rating); c.players.splice(0, 2);
    const [ready, crack, plain] = a.players;
    // Niveau du match (niveauMatch : Niveau au rôle, calculé sur les qualités, 25/11/2026) : l'espoir prêt reprend les
    // qualités du moins bon pro de son poste, l'espoir ordinaire les mêmes moins 15 points.
    const peers = c.players.filter(q => q.fam === ready.fam);
    const weakestPro = peers.reduce((m, q) => niveauMatch(q) < niveauMatch(m) ? q : m, peers[0]);
    const aligne = (p, k) => {
      const src = JSON.parse(JSON.stringify(weakestPro));
      for (const f of ['pos', 'fam', 'skills', 'attributesV2', 'nativeAttributesV1']) if (src[f] !== undefined) p[f] = src[f]; else delete p[f];
      p.rating = src.rating + k; p.skillBase = (src.skillBase ?? src.rating) + k;
      if (k) { for (const s in p.skills || {}) p.skills[s] = Math.max(1, p.skills[s] + k);
        if (p.attributesV2) for (const s in p.attributesV2) if (typeof p.attributesV2[s] === 'number') p.attributesV2[s] = Math.max(1, p.attributesV2[s] + k);
        if (typeof p.nativeAttributesV1 === 'string' && /^\d{72}$/.test(p.nativeAttributesV1)) p.nativeAttributesV1 = p.nativeAttributesV1.match(/\d\d/g).map(v => String(Math.max(20, +v + k)).padStart(2, '0')).join(''); }
      delete p.roleId;
    };
    for (const p of [ready, crack, plain]) { p.age = 19; p.injury = 0; p.salary = floor; }
    aligne(ready, 0); aligne(plain, -15);
    crack.rating = 40; crack.dev.potential = 92;
    plain.dev.potential = 70;
    if (!(niveauMatch(ready) >= niveauMatch(weakestPro) - 2) || !(niveauMatch(plain) < niveauMatch(weakestPro) - 2)) throw Error('banc des espoirs mal préparé');
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
