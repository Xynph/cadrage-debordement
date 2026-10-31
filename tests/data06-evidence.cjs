'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validate,matchRoster,estimateAttributes,load}=require('../tools/data06-evidence.cjs');
const source=load();
test('real LNR transfer evidence is internally valid',()=>{
 const report=validate(source);assert.equal(report.entries,24);assert.equal(report.clubs,3);assert.equal(report.financialFacts,0);
});
test('duplication, invented finances and historical claims are rejected',()=>{
 const copy=structuredClone(source);copy.records.push({...copy.records[0]});assert.throws(()=>validate(copy),/Duplicate/);
 const fake=structuredClone(source);fake.records[0].verifiedSalary=1000;assert.throws(()=>validate(fake),/Unverified/);
 fake.records[0].verifiedSalary=null;fake.records[0].historicalAsOfJuly1Verified=true;assert.throws(()=>validate(fake),/Unverified/);
});
test('no automatic ambiguous identity mapping',()=>{
 const roster=[{id:'lnr:1',club:'clermont',name:'Justin BOURAUX'},{id:'lnr:2',club:'other',name:'Baptiste GERMAIN'}];
 const report=matchRoster(source,roster);
 assert.equal(report.matched,1);assert.equal(report.review,1);assert.equal(report.unknown,22);
 assert.equal(report.results[1].linkedId,null);
});
test('rating estimation is explicitly nonofficial and null without verified stats',()=>{
 assert.equal(estimateAttributes(source.records[0]).rating,null);
 assert.equal(estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).kind,'game-estimate');
 assert.equal(estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).rating,estimateAttributes(source.records[0],{matches:3,minutes:250,tries:1}).rating);
});
