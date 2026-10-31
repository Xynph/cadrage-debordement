'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validate,matchRoster,estimateAttributes,load}=require('../tools/data06-evidence.cjs');
const source=load();
test('real LNR transfer evidence is internally valid',()=>{
 const report=validate(source);assert.equal(report.entries,98);assert.equal(report.clubs,14);assert.equal(report.financialFacts,0);
});
test('duplication, invented finances and historical claims are rejected',()=>{
 const copy=structuredClone(source);copy.records.push({...copy.records[0]});assert.throws(()=>validate(copy),/Duplicate/);
 const fake=structuredClone(source);fake.records[0].verifiedSalary=1000;assert.throws(()=>validate(fake),/Unverified/);
 fake.records[0].verifiedSalary=null;fake.records[0].historicalAsOfJuly1Verified=true;assert.throws(()=>validate(fake),/Unverified/);
});
test('no automatic ambiguous identity mapping',()=>{
 const roster=[{id:'lnr:1',club:'clermont',name:'Justin BOURAUX'},{id:'lnr:2',club:'other',name:'Baptiste GERMAIN'}];
 const report=matchRoster(source,roster);
 assert.equal(report.matched,1);assert.equal(report.review,1);assert.equal(report.unknown,96);
 assert.equal(report.results[1].linkedId,null);
});
test('rating estimation is explicitly nonofficial and null without verified stats',()=>{
 assert.equal(estimateAttributes(source.records[0]).rating,null);
 assert.equal(estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).kind,'game-estimate');
 assert.equal(estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).rating,estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).rating);
});

test('crosschecks actual 1592 player IDs without guessing ambiguous matches',()=>{
 const path=require('node:path');
 const root=path.resolve(__dirname,'..');
 const roster=['top14-a','top14-b','prod2-a','prod2-b'].flatMap(file=>require(path.join(root,'modding/data03',file+'.json')).clubs).flatMap(c=>c.players.map(p=>({...p,club:c.club})));
 assert.equal(roster.length,1592);
 const result=matchRoster(source,roster);
 assert.equal(result.results.length,98);
 assert.equal(result.matched+result.review+result.unknown,80);
 const linked=result.results.filter(x=>x.linkedId!==null);
 assert.equal(new Set(linked.map(x=>x.linkedId)).size,linked.length);
 assert.ok(result.results.every(x=>x.linkedId===null||x.status==='club-match'));
});

test('published 80-transfer reconciliation is complete, unique and never guesses missing IDs',()=>{
 const r=require('../modding/data06/transfer-reconciliation-2026-2027.json');
 assert.deepEqual(r.summary,{total:98,exact:52,review:12,missing:34});
 assert.equal(r.records.length,source.records.length);
 const roster=['top14-a','top14-b','prod2-a','prod2-b'].flatMap(file=>require('../modding/data03/'+file+'.json').clubs).flatMap(c=>c.players.map(p=>({...p,club:c.club})));
 const byId=new Map(roster.map(p=>[p.id,p]));
 for(const e of r.records){
  if(e.status==='exact-club-match'){
   assert.ok(e.mappedId);assert.equal(byId.get(e.mappedId)?.club,e.arrivalClub);
  }else{assert.equal(e.mappedId,null);assert.equal(e.autoImported,false)}
 }
 assert.equal(new Set(r.records.filter(x=>x.mappedId).map(x=>x.mappedId)).size,52);
});
