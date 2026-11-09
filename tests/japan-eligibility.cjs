'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {registration,teamSheet,substitution,planSheet}=require('../native/engine/japan-eligibility.cjs');
const players=(category,count,prefix=category)=>Array.from({length:count},(_,i)=>({id:prefix+'-'+i,category}));
const xv=[...players('A-1',8,'a'),...players('A-2',2,'a2'),...players('B',2,'b'),...players('C',3,'c')];
const bench=[...players('A-1',6,'aa'),...players('A-2',1,'bb'),...players('B',1,'bb2')];

test('Effectif inscrit : 10 B+C et 3 C ; inconnu ne veut pas dire A-1',()=>{
 const roster=[...players('A-1',20),...players('A-2',5),...players('B',7),...players('C',3)];
 assert.equal(registration(roster).valid,true);
 assert.ok(registration([...roster,...players('B',1,'surplus')]).violations.includes('registered-bc'));
 assert.ok(registration([...roster,{id:'x',nationality:'JP'}]).violations.includes('unknown-category'));
 assert.ok(registration([...roster,...players('C',1,'surplus')]).violations.includes('registered-c'));
});

test('Feuilles de 23 ou 22 et joueurs simultanés : appliquer chaque seuil officiel',()=>{
 assert.equal(teamSheet(xv,bench,{frontRow:6}).valid,true);
 assert.equal(teamSheet(xv,bench.filter(p=>p.id!=='aa-0'),{frontRow:5}).valid,true);
 assert.ok(teamSheet(xv,bench,{frontRow:5}).violations.includes('sheet-size'));
 const changed=xv.map(p=>p.id==='a-0'?{...p,category:'B'}:p);
 const bad=teamSheet(changed,bench,{frontRow:6});
 assert.ok(bad.violations.includes('sheet-a1'));
 assert.ok(bad.violations.includes('field-a1'));
 assert.ok(teamSheet(xv,[...bench.slice(0,-1),{id:'overflow',category:'C'}],{frontRow:6}).violations.includes('sheet-c'));
 assert.ok(teamSheet(xv,[...bench.slice(0,-1),xv[0]],{frontRow:6}).violations.includes('duplicate-player'));
});

test('Remplacement : le quota terrain ne doit jamais être dégradé après une exclusion',()=>{
 assert.equal(substitution(xv,'a-0',bench[0]).valid,true);
 assert.equal(substitution(xv,'a-0',bench.at(-1)).valid,false);
 const reduced=xv.filter(p=>p.id!=='a-0');
 assert.equal(substitution(reduced,'a-1',bench.at(-1),{forcedAbsence:true}).valid,false);
 assert.equal(substitution(reduced,'a2-0',bench[0],{forcedAbsence:true}).valid,true);
 assert.equal(substitution(reduced,'c-0',xv[1],{forcedAbsence:true}).valid,false);
});

test('Le solveur construit une feuille légale avec alternatives de postes sans doublon',()=>{
 const all=xv.concat(bench);
 const slots=all.map((p,i)=>({slot:i,starter:i<15,candidates:[{id:'star-'+i,category:'C',rank:99},{...p,rank:90}]}));
 const plan=planSheet(slots,{frontRow:6});
 assert.equal(plan.valid,true);
 assert.equal(plan.assignment.length,23);
 assert.equal(new Set(plan.assignment.map(p=>p.id)).size,23);
 assert.equal(teamSheet(plan.assignment.slice(0,15),plan.assignment.slice(15),{frontRow:6}).valid,true);
 assert.ok(plan.assignment.some(p=>p.id.startsWith('star-')));
 const impossible=slots.map((s,i)=>i<2?{...s,candidates:[xv[0]]}:s);
 assert.deepEqual(planSheet(impossible,{frontRow:6}).violations,['no-legal-sheet']);
 const inconsistent=slots.map((s,i)=>i===1?{...s,candidates:[{id:xv[0].id,category:'C'}]}:s);
 assert.throws(()=>planSheet(inconsistent,{frontRow:6}),/catégorie contradictoire/i);
 const inside=slots.map((s,i)=>i===0?{...s,candidates:[xv[0],{...xv[0],category:'C'}]}:s);
 assert.throws(()=>planSheet(inside,{frontRow:6}),/catégorie contradictoire/i);
});
