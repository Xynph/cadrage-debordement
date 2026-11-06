'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {evaluate,ROLES}=require('../tools/rugby-real-promotion-tier-v10.cjs');
const spec=[...new Set(Object.values(ROLES).flat())];
function fixture(top=78,pro=73){
 const roles=Object.keys(ROLES);
 return {players:Array.from({length:1592},(_,i)=>{
  const league=i<805?'top14':'prod2',role=roles[i%roles.length];
  const attrs=Object.fromEntries([...spec,...Array.from({length:36-spec.length},(_,k)=>'other'+k)].map(k=>[k,Math.min(97,(league==='top14'?top:pro)+(i%3))]));
  return {id:'p'+i,league,gameplayPosition:role,attributesV2:attrs,hiddenTraitsV2:{one:50},potential:80};
 })};
}
test('all 1592 candidates no master mutation',()=>{
 const m=fixture(),old=JSON.stringify(m),r=evaluate(m);
 assert.equal(r.candidates.length,1592);assert.equal(JSON.stringify(m),old);
 assert.equal(r.summary.top14,805);assert.equal(r.summary.prod2,787);
});
test('harder TOP14 target with preserved stars in PRO D2',()=>{
 const r=evaluate(fixture());
 assert.ok(Object.values(r.roleAudit).every(x=>x.gapAfter>=x.gapBefore&&x.targetReached));
 assert.ok(r.candidates.filter(x=>x.leagueAtStart==='prod2').every(x=>x.changes.length===0));
});
test('no arbitrary boost if target already exceeded',()=>{
 const r=evaluate(fixture(82,67));
 assert.equal(r.summary.affectedPlayers,0);
 assert.ok(Object.values(r.roleAudit).every(x=>x.proposedTop14Bonus===0));
});
test('a promoted team does not receive instant TOP14 boost and relegated stays strong',()=>{
 const r=evaluate(fixture());
 assert.equal(r.transitions.promotion.automaticLeagueBonusToPromoted,0);
 assert.equal(r.transitions.relegation.automaticLeagueNerfToRelegated,0);
});
test('bonus capped and notes never exceed 97',()=>{
 const r=evaluate(fixture(97,96),{targetGap:9});
 assert.ok(Object.values(r.roleAudit).some(x=>!x.targetReached));
 assert.ok(r.candidates.flatMap(x=>x.changes).every(x=>x.to<=97&&x.delta<=5));
});
test('duplicate ID rejected',()=>{
 const m=fixture();m.players[1].id=m.players[0].id;
 assert.throws(()=>evaluate(m),/Duplicate/);
});
