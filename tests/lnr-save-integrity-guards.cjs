'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const modules=['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'];
function career(){
 const t=context();
 for(const moduleName of modules)vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+moduleName,'utf8'),t.ctx);
 t.run("start(0,'lnr')");
 for(let i=0;i<7;i++)t.run('trainWeek();finishRound()');
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
 test('LNR save rejects '+name+' without altering live career',()=>{
  const t=career();
  const exported=t.run('JSON.stringify(createSaveDocument())');
  assert.equal(t.run('!!parseSaveDocument('+JSON.stringify(exported)+')'),true);
  const original=t.run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
  const bad=JSON.parse(exported);mutate(bad);
  assert.throws(()=>t.run('parseSaveDocument('+JSON.stringify(JSON.stringify(bad))+')'));
  assert.equal(t.run('JSON.stringify(S)'),original,'live career preserved');
  assert.equal(t.store['bdt-v1'],disk,'disk career preserved');
 });
}
