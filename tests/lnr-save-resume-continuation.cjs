'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const modules=['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'];
function load(saved){
 const t=context();
 for(const name of modules)vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+name,'utf8'),t.ctx);
 if(saved)t.run('S=parseSaveDocument('+JSON.stringify(saved)+').state');
 else t.run("start(0,'lnr')");
 return t;
}
function step(t,policy){
 if(policy==='weekly')t.run("club().players.forEach(p=>{if(p.physicalLoad&&p.physicalLoad.plan==='repos')p.physicalLoad.plan='normal'})");
 t.run("club().players.filter(p=>p.condition<65||physicalLoadValue(p)>45).forEach(p=>setPhysicalTraining(p.id,'repos'))");
 t.run('trainWeek();finishRound()');
}
for(const policy of ['persistent','weekly']){
 test('LNR: import natif puis reprise effective de saison ('+policy+')',()=>{
  const before=load();
  let total=0;
  for(;total<15;total++)step(before,policy);
  assert.notEqual(before.run('S.phase'),'ended');
  const exported=before.run('JSON.stringify(createSaveDocument())');
  assert.equal(before.run('!!parseSaveDocument('+JSON.stringify(exported)+')'),true);
  const restored=load(exported);
  const snapshot=t=>t.run('JSON.stringify({round:S.round,phase:S.phase,won:club().won,players:club().players.map(p=>({id:p.id,condition:p.condition,physicalLoad:p.physicalLoad,injury:p.injury}))})');
  assert.equal(snapshot(restored),snapshot(before),'state must survive serialization exactly');
  const initialRound=restored.run('S.round');
  const initialWins=restored.run('club().won');
  for(let i=0;i<3;i++){step(restored,policy);total++;}
  assert(restored.run('S.round')!==initialRound || restored.run('S.phase')==='ended','imported state must advance');
  assert(restored.run('club().won')>=initialWins);
  assert.equal(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true,'continued state remains exportable');
  while(restored.run("S.phase!=='ended'")&&total<42){step(restored,policy);total++;}
  assert.equal(restored.run('S.phase'),'ended','imported season must complete');
  assert(total>=25&&total<=42,'plausible number of rounds');
  console.log(JSON.stringify({passed:true,policy,checkpointRound:initialRound,rounds:total,wins:restored.run('club().won'),continuedRounds:total-15,exportAfterResume:true}));
 });
}
