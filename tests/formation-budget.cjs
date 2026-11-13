'use strict';
// Budget du centre de formation, cohérent entre les pays (demande de Léo du 13/11/2026).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const B = require('../native/engine/club-budget.cjs');

const forces = [
  { id: 0, division: 'elite', base: 80 }, { id: 1, division: 'elite', base: 70 },
  { id: 2, division: 'prem', base: 78 }, { id: 3, division: 'prem', base: 68 },
  { id: 4, division: 'urc', base: 76 }, { id: 5, division: 'urc', base: 66 },
  { id: 6, division: 'jlo-d1', base: 74 }, { id: 7, division: 'jlo-d1', base: 64 },
];
const week = (clubId, formation) => B.semaine({ forces, clubId, masseHebdo: 50000, semaines: 46, domicile: false, alea: 0.5, libelle: 'S1', formation });
const total = rows => rows.reduce((s, e) => s + e.amount, 0);
const line = (rows, pattern) => rows.find(e => pattern.test(e.title))?.amount ?? 0;

test('Un centre de référence (30 Crabos, 30 Espoirs) ne change pas le résultat du club', () => {
  for (const club of forces) {
    const rows = week(club.id, { crabos: 30, espoirs: 30 });
    const annuel = B.recettes(forces).get(club.id);
    const expected = -Math.round(annuel * B.FONCTIONNEMENT / 46 / 100) * 100;
    const operations = line(rows, /fonctionnement/) + line(rows, /Centre de formation/) + rows.filter(e => e.amount > 0 && !/Partenaires|ligue|Subventions|Abonnements/.test(e.title)).reduce((s, e) => s + e.amount, 0);
    assert.ok(Math.abs(operations - expected) <= 300, `${club.division} : ${operations} contre ${expected}`);
    assert.deepEqual(rows.map(e => e.amount), week(club.id, null).map(e => e.amount), 'sans effectif connu, le centre de référence');
  }
});

test('Le centre coûte selon son effectif ; un Espoir coûte plus qu’un Crabos', () => {
  const small = total(week(0, { crabos: 20, espoirs: 20 })), ref = total(week(0, { crabos: 30, espoirs: 30 })), big = total(week(0, { crabos: 35, espoirs: 40 }));
  assert.ok(small > ref && ref > big);
  const crabe = total(week(0, { crabos: 31, espoirs: 30 })) - ref, espoir = total(week(0, { crabos: 30, espoirs: 31 })) - ref;
  assert.ok(espoir < crabe && crabe < 0, `${crabe} / ${espoir}`);
});

test('Les aides suivent l’organisation de chaque pays', () => {
  const share = id => { const rows = week(id, { crabos: 30, espoirs: 30 }); const aide = rows.filter(e => e.amount > 0 && /(formation|académie)/i.test(e.title)).reduce((s, e) => s + e.amount, 0); return aide / -line(rows, /Centre de formation/); };
  assert.ok(Math.abs(share(0) - 0.25) < 0.01, 'France : LNR et région');
  assert.ok(Math.abs(share(2) - 0.4) < 0.01, 'Angleterre : fédération');
  assert.ok(Math.abs(share(4) - 0.7) < 0.01, 'Celtes : fédération');
  assert.equal(share(6), 0, 'Japon : club d’entreprise');
  const gross = id => -line(week(id, null), /Centre de formation/) * 46;
  assert.ok(gross(0) > 1.2e6 && gross(0) < 2.5e6, `Top 14 : ${gross(0)}`);
  assert.ok(gross(0) > gross(1), 'un grand club dépense plus');
});

test('Crédit académie : seulement en Angleterre, joueurs formés au club, au plus 6', () => {
  const homegrown = n => Array.from({ length: n }, (_, i) => ({ id: `youth-2-3-${i}`, age: 21, salary: 1500 }));
  assert.equal(B.creditAcademie('prem', homegrown(4), 2), 4 * 115000);
  assert.equal(B.creditAcademie('prem', homegrown(9), 2), 6 * 115000);
  assert.equal(B.creditAcademie('elite', homegrown(4), 0), 0);
  assert.equal(B.creditAcademie('prem', [{ id: 'youth-3-3-1', age: 21, salary: 1500 }], 2), 0, 'formé ailleurs');
  assert.equal(B.creditAcademie('prem', [{ id: 'youth-2-3-1', age: 24, salary: 1500 }], 2), 0, 'trop âgé');
  assert.equal(B.creditAcademie('prem', [{ id: 'youth-2-3-1', age: 21, salary: 900 }], 2), 0, 'salaire trop bas');
  const without = B.limites(forces, 1), withCredit = B.limites(forces, 1, { credits: { 2: 690000 } });
  assert.ok(withCredit.get(2).limite >= without.get(2).limite);
  assert.equal(withCredit.get(0).limite, without.get(0).limite);
});
