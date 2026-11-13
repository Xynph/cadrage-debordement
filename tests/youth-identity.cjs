'use strict';
// Origine, nom et éligibilité des jeunes générés (décisions de Léo du 12/11/2026).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./france-harness.cjs');
const playerFacts = require('../native/engine/player-facts.cjs');

const anchors = ['FRA', 'ENG', 'SCO', 'WAL', 'IRE', 'ITA', 'RSA', 'NZL', 'AUS', 'FIJ', 'GEO', 'JPN'];

test('Même origine côté jeu et côté éligibilité, mélange réaliste par pays', () => {
  const h = context(437493);
  const clubs = Object.fromEntries(anchors.map((nation, i) => [i, nation]));
  const facts = playerFacts({}, {}, clubs);
  const codes = Object.fromEntries(Object.entries(facts.nations).map(([code, [name]]) => [name, code]));
  for (const [i, anchor] of anchors.entries()) {
    const ids = Array.from({ length: 400 }, (_, n) => `youth-${i}-3-${n}`);
    const game = JSON.parse(h.run(`JSON.stringify(${JSON.stringify(ids)}.map(id => youthHeritage(id, ${JSON.stringify(anchor)})))`));
    const native = ids.map(id => codes[facts.project(id).nationality]);
    assert.deepEqual(game, native, anchor);
    const local = game.filter(n => n === anchor).length / game.length;
    assert.ok(local >= .66, `${anchor} : ${local}`);
  }
});

test('Un jeune d’origine étrangère formé au club est sélectionnable pour les deux pays, pas pour un troisième', () => {
  const facts = playerFacts({}, {}, { 7: 'NZL' });
  const id = Array.from({ length: 500 }, (_, n) => `youth-7-2-${n}`).find(x => facts.project(x).nationality === 'Samoa');
  assert.ok(id);
  assert.equal(facts.eligible(id, 'SAM'), true);
  assert.equal(facts.eligible(id, 'NZL'), true);
  assert.equal(facts.eligible(id, 'AUS'), false);
});

test('Noms : style du pays d’origine en carrière mondiale, France inchangée', () => {
  const h = context(437493);
  const r = JSON.parse(h.run(`(() => {
    const france = academyPlayer(3, 4, 2, 9, false, { id: 3, country: 'FR' }).name;
    const legacy = (() => { const id = 'youth-3-2-9', k = seedHash(id); return FIRST[k % FIRST.length] + ' ' + LAST[Math.floor(k / 31) % LAST.length]; })();
    const saved = worldActive; worldActive = () => true;
    try {
      const japan = Array.from({ length: 60 }, (_, n) => academyPlayer(60, n % 15, 2, n, false, { id: 60, country: 'JP' }))
        .map(p => [youthHeritage(p.id, 'JPN'), p.name]);
      const wales = academyPlayer(47, 1, 2, 4, false, { id: 47, country: 'GB' });
      return JSON.stringify({ france, legacy, japan, walesNation: youthHeritage(wales.id, 'WAL'), wales: wales.name });
    } finally { worldActive = saved; }
  })()`));
  assert.equal(r.france, r.legacy, 'En carrière France, le tirage historique est conservé');
  const japanese = r.japan.filter(([nation]) => nation === 'JPN').map(([, name]) => name);
  assert.ok(japanese.length >= 45);
  assert.ok(japanese.every(name => /^(Daiki|Haruki|Haruto|Hiroto|Kaito|Kenta|Kota|Riku|Ryota|Shota|Sota|Takumi|Yuma|Yuto) /.test(name)), JSON.stringify(japanese.slice(0, 5)));
  assert.equal(new Set(r.japan.map(([, name]) => name)).size > 40, true, 'Peu de doublons');
  assert.ok(r.wales.length > 3);
});
