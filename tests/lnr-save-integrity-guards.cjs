'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {engineContext:context}=require('./harness.cjs');
const modules=['lnr-rosters-base.js','lnr-career.js','lnr05-mesures.js','lnr05-evidence-center.js'];
// Les cinq attaques partent du même point réel, comme les démarrages déterministes
// initiaux ; chaque VM recharge une copie distincte, jamais une référence partagée.
let baseline;
function career(){
 if(!baseline){
  const t=context();
  try{t.start(0);t.deferSaves();for(let i=0;i<7;i++)t.run('trainWeek();finishRound()');
   baseline={state:t.state(),seed:t.seed(),text:t.run('JSON.stringify(S)')};
  }finally{t.close();}
 }
 const t=context(baseline.state);t.setSeed(baseline.seed);
 assert.ok(t.run('JSON.stringify(S)')===baseline.text,'fixture Monde strictement identique après reprise');
 return t;
}
const attacks=[
 ['checksum mismatch',doc=>{doc.checksum='00000000';}],
 ['tampered condition',doc=>{doc.state.clubs[doc.state.club].players[0].condition=1;}],
 ['tampered club identity',doc=>{doc.state.club=999;}],
 ['unsupported export version',doc=>{doc.exportVersion=999;}],
 ['broken roster',doc=>{doc.state.clubs[doc.state.club].players=null;}]
];
for(const [name,mutate] of attacks){
 test('Monde save rejects '+name+' without altering live career',()=>{
  const t=career();try{
  const exported=t.run('JSON.stringify(createSaveDocument())');
  assert.equal(t.run('!!parseSaveDocument('+JSON.stringify(exported)+')'),true);
  const original=t.run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
  const bad=JSON.parse(exported);mutate(bad);
  assert.throws(()=>t.run('parseSaveDocument('+JSON.stringify(JSON.stringify(bad))+')'));
  assert.equal(t.run('JSON.stringify(S)'),original,'live career preserved');
  assert.equal(t.store['bdt-v1'],disk,'disk career preserved');
  }finally{t.close();}
 });
}
