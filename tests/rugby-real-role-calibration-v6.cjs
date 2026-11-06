'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {calibrate,PRIORITIES}=require('../tools/rugby-real-role-calibration-v6.cjs');
const keys=[...new Set(Object.values(PRIORITIES).flat())];
function fixture(){
  const roles=Object.keys(PRIORITIES),players=[];
  for(let i=0;i<1592;i++){
    const league=i<805?'top14':'prod2',r=roles[i%roles.length];
    players.push({id:'p-'+i,league,gameplayPosition:r,gameplayPositionEstimated:true,
      attributesV2:Object.fromEntries(Array.from({length:36},(_,k)=>['k'+k,60+(i%7)]).concat(keys.map((x,k)=>[x,45+(i%19)+(k%6)]))),
      potential:80,hiddenTraitsV2:{professionalism:50,consistency:50,bigMatches:50,injuryResistance:50,ambition:50,loyalty:50}});
  }
  return {players};
}
test('all 1592 players get exactly one non-destructive candidate',()=>{
  const root=fixture(),baseline=JSON.stringify(root),r=calibrate(root);
  assert.equal(r.candidates.length,1592);assert.equal(r.summary.players,1592);
  assert.equal(JSON.stringify(root),baseline);
});
test('every adjustment within +/-2 and role specialist only',()=>{
  const r=calibrate(fixture());
  for(const p of r.candidates)for(const x of p.changes){
    assert.ok(PRIORITIES[p.gameplayPosition].slice(0,4).includes(x.attribute));
    assert.ok(Math.abs(x.delta)<=2);
    assert.ok(x.to>=20&&x.to<=97);
    assert.equal(x.evidence,'model-estimate');
  }
});
test('unknown role fails closed',()=>{
  const root=fixture();root.players[0].gameplayPosition='Unknown';
  assert.throws(()=>calibrate(root),/Unknown league\/role/);
});
test('duplicate stable id fails closed',()=>{
  const root=fixture();root.players[1].id=root.players[0].id;
  assert.throws(()=>calibrate(root),/duplicate stable/);
});