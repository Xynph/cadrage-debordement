'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {load,loadRoster,reconcile}=require('../tools/data06-roster-batch.cjs');
const root=path.resolve(__dirname,'..');
test('published 90 rows are reconciled against all 1592 identities without fake attributes',()=>{
 const roster=loadRoster(root),evidence=load(root),out=reconcile(evidence,roster);
 assert.equal(roster.length,1592);assert.equal(evidence.clubs.length,4);
 assert.equal(out.summary.published,90);
 assert.equal(out.summary.matched+out.summary.unresolved,90);
 assert.equal(new Set(out.matches.map(p=>p.id)).size,out.matches.length);
 assert.ok(out.matches.every(p=>p.gameRating===null&&p.matches===null&&p.minutes===null&&p.points===null&&p.historicalAsOfJuly1Verified===false&&p.sourceUrl.includes('lnr.fr')));
});
test('ambiguous entries are never linked or manufactured',()=>{
 const doc=structuredClone(load(root));doc.clubs[0].players[0].name='Invented Unknown';
 const result=reconcile(doc,loadRoster(root));assert.ok(result.unresolved.some(p=>p.name==='Invented Unknown'));
});
test('reject invalid public stats and fabricated LNR sources',()=>{
 const doc=structuredClone(load(root));doc.clubs[0].players[0].minutes=999999;
 assert.throws(()=>reconcile(doc,loadRoster(root)),/Invalid/);
 doc.clubs[0].players[0].minutes=null;doc.clubs[0].sourceUrl='https://attacker.invalid/';assert.throws(()=>reconcile(doc,loadRoster(root)),/Invalid LNR/);
});
