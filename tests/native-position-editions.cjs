'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs');
const {createBridge}=require('../native/engine/worker.cjs');
for(const [mode,club] of [['world-japan',68],['world-nationale',88]]){
 const root=fs.mkdtempSync('/tmp/cd-position-edition-'),start=performance.now(),bridge=createBridge({dataDir:root,seed:213,now:1700000000000});let id=0;
 const request=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,mode+' '+command+': '+r.error);return r.model;};
 try {
  let model=settleClubMeetings(request('new_career',{mode,club}),request);model=request('auto_lineup');
  assert.equal(model.club.id,club);assert.equal(model.selection.valid,true,model.selection.errors.join(';'));
  const all=[...model.lineup,...model.reserves];assert.equal(new Set(all).size,23);
  for(const slot of [0,1,2,15,16,17]){
   const p=model.squad.find(p=>p.id===all[slot]);assert.ok(p.qualifiedFrontRowPositions.includes(model.selection.slots[slot].positionNumber));
  }
  if(mode==='world-japan'){
   assert.equal(model.japanEligibility.valid,true);
   assert.ok(all.every(id=>model.squad.find(p=>p.id===id).japanRegistered));
   assert.ok(model.selection.slots.every(s=>s.eligibleIds.every(id=>model.squad.find(p=>p.id===id).japanRegistered)));
  }
  const text=request('export').meta.exportText;model=request('import',{text});assert.deepEqual([...model.lineup,...model.reserves],all);
  console.log(JSON.stringify({mode,ms:Math.round(performance.now()-start),front:all.filter((_,i)=>[0,1,2,15,16,17].includes(i))}));
 }finally{bridge.close();fs.rmSync(root,{recursive:true,force:true});}
}
