'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {build}=require('../tools/data06-all-players.cjs');
test('full real corpus has 30 clubs and 1592 stable unique IDs',()=>{
 const d=build();assert.equal(d.summary.clubs,30);assert.equal(d.players.length,1592);
 assert.equal(new Set(d.players.map(p=>p.id)).size,1592);
 assert.equal(d.summary.individualProfiles,240);assert.equal(d.summary.rosterOnly,1352);
});
test('all profiles preserve LNR URL, original club and explicit unknowns',()=>{
 const d=build();for(const p of d.players){
  assert.match(p.id,/^lnr:\d+$/);assert.match(p.url,/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\//);
  assert.equal(p.salary,null);assert.equal(p.clubBudget,null);assert.equal(p.gameRatingEstimate,null);
  assert.equal(p.historicalAsOfJuly1Verified,false);assert.equal(p.birthDate,null);
  if(!p.profileEnriched){assert.equal(p.ageReported,null);assert.equal(p.heightCm,null);assert.equal(p.weightKg,null)}
 }
});
test('no fabricated positions, game ratings or contracts',()=>{
 const d=build();assert.ok(d.players.every(p=>p.contractEnd===null&&p.actualPerformance===null));
 assert.equal(d.players.filter(p=>p.profileEnriched).length,240);
});
