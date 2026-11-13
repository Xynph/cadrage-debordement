'use strict';
// Jeunes des centres japonais et catégories League One 2026-27 (A-1 : 6 des 9 années de scolarité
// obligatoire au Japon ; A-2 : 48 mois d'enregistrement continu sans sélection d'une autre union ;
// B : jeune étranger avant ses 48 mois). Origine = youthHeritage() de dist/development.js.
const { test } = require('node:test');
const a = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const Q = require('../native/engine/japan-quota-runtime.cjs');
const eligibility = require('../native/engine/japan-eligibility.cjs');

function setup() {
  const h = context(437493);
  h.run(`var Q = (${Q.factory.toString()})({categories: ['A-1', 'A-2', 'B', 'C']});`);
  return h;
}

test('un jeune d’un centre japonais : origine japonaise = A-1, origine étrangère = B puis A-2 après 48 mois', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(function () {
    const out = { jp: [], foreign: [] };
    for (let k = 0; k < 400; k++) {
      const id = 'youth-70-5-' + k, origin = youthHeritage(id, 'JPN');
      const bucket = origin === 'JPN' ? out.jp : out.foreign;
      const young = { id, age: 19 };
      bucket.push([Q.youthCategory({ season: 5 }, young).category, Q.youthCategory({ season: 8 }, young).category, origin]);
    }
    return JSON.stringify({ jp: [...new Set(out.jp.map(x => x[0] + x[1]))], foreign: [...new Set(out.foreign.map(x => x[0] + '>' + x[1]))], nJp: out.jp.length, nForeign: out.foreign.length });
  })()`));
  a.deepEqual(r.jp, ['A-1A-1'], 'les jeunes d’origine japonaise sont A-1 dès l’arrivée');
  a.deepEqual(r.foreign, ['B>B']);
  a.ok(r.nJp > 300 && r.nForeign > 20, `${r.nJp}/${r.nForeign}`);
});

test('48 mois : saison d’arrivée + 4 pour une génération ordinaire, âge − 16 ans pour la génération initiale', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(function () {
    let foreign = null;
    for (let k = 0; !foreign; k++) { const id = 'youth-70-5-' + k; if (youthHeritage(id, 'JPN') !== 'JPN') foreign = id; }
    let initial = null;
    for (let k = 0; !initial; k++) { const id = 'youth-70-1-' + k; if (youthHeritage(id, 'JPN') !== 'JPN') initial = id; }
    const cat = (id, season, age) => Q.youthCategory({ season }, { id, age }).category;
    return JSON.stringify({ s8: cat(foreign, 8, 20), s9: cat(foreign, 9, 21), s6: cat(foreign, 6, 18),
      initial20: cat(initial, 1, 20), initial19: cat(initial, 1, 19), initial21: cat(initial, 1, 21) });
  })()`));
  a.equal(r.s8, 'B', '3 saisons : pas encore 48 mois');
  a.equal(r.s9, 'A-2', '4 saisons : A-2');
  a.equal(r.s6, 'B');
  a.equal(r.initial19, 'B');
  a.equal(r.initial20, 'A-2');
  a.equal(r.initial21, 'A-2');
});

test('autres identifiants : promus de secours japonais A-1, recrues non vérifiées C, centres hors Japon C', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify(['jlo-academy-70-1-3-1', 'youth-10-1-1', 'p70-1', 'youth-87-3-2', 'youth-88-3-2'].map(id => Q.youthCategory({ season: 3 }, { id, age: 20 }).category))`));
  a.equal(r[0], 'A-1');
  a.equal(r[1], 'C');
  a.equal(r[2], 'C');
  a.ok(['A-1', 'B'].includes(r[3]));
  a.equal(r[4], 'C');
});

test('terrain : jamais plus de 4 joueurs B ensemble (règlement 2026-27)', () => {
  const rows = (cat, n) => Array.from({ length: n }, (_, i) => ({ id: cat + i, category: cat }));
  const A = rows('A-1', 12), B = rows('B', 8);
  a.equal(eligibility.substitution([...A.slice(0, 8), ...B.slice(0, 4)], A[0].id, B[4]).valid, false);
  a.ok(eligibility.substitution([...A.slice(0, 8), ...B.slice(0, 4)], A[0].id, B[4]).violations.includes('field-b'));
  a.equal(eligibility.teamSheet([...A.slice(0, 8), ...B.slice(0, 5)].slice(0, 15).concat(rows('A-2', 2)), [...A.slice(8, 12), ...rows('A-1', 4)], { frontRow: 6 }).violations.includes('field-b'), true);
  a.equal(Q.partialSheet([...A.slice(0, 8), ...B.slice(0, 5)], []), false);
  a.equal(Q.partialSheet([...A.slice(0, 11), ...B.slice(0, 4)], []), true);
});
