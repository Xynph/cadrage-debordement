'use strict';
// Prêt d'une piste du marché (rapport du recruteur, 22/11/2026), carrière Monde (world-champ) :
// jeune (23 ans ou moins) ou hors des 23 meilleures notes de son club → prêt possible ; sinon « cadre ».
const test = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

let h = null;
test.after(() => h?.close());

test('Chaque piste du marché porte son prêt : possible si jeune ou hors des 23 de son club', () => {
  h = context(827381);
  const r = JSON.parse(h.run(`(()=>{const m=nativeModel();
   // Cas fabriqués sur des copies : club identifié de 30 joueurs, piste la plus faible puis la plus forte.
   const ci=S.clubs.findIndex(c=>c.id!==S.club&&c.players.length>=26),c=S.clubs[ci];
   const notes=c.players.map(p=>p.rating).sort((a,b)=>a-b);
   const base=S.market[0],copie=(age,rating)=>({...JSON.parse(JSON.stringify(base)),id:'test-pret-'+age+'-'+rating,age,rating,population:{...base.population,clubId:ci}});
   const avant=S.market;S.market=[copie(20,notes[notes.length-1]+1),copie(30,notes[0]-1),copie(30,notes[notes.length-1]+1)];
   const cas=nativeModel().market.map(p=>p.loan);S.market=avant;
   return JSON.stringify({pistes:m.market.map(p=>({age:p.age,loan:p.loan})),cas});})()`));
  assert.ok(r.pistes.length > 0, 'marché non vide');
  for (const p of r.pistes) {
    assert.deepEqual(Object.keys(p.loan).sort(), ['possible', 'reason']);
    if (p.age <= 23) assert.deepEqual(p.loan, { possible: true, reason: 'jeune' });
    else assert.ok(['hors-23', 'cadre'].includes(p.loan.reason) && p.loan.possible === (p.loan.reason === 'hors-23'));
  }
  assert.deepEqual(r.cas[0], { possible: true, reason: 'jeune' });
  assert.deepEqual(r.cas[1], { possible: true, reason: 'hors-23' });
  assert.deepEqual(r.cas[2], { possible: false, reason: 'cadre' });
});
