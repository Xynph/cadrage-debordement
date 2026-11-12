'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {createTransport}=require('../native/engine/model-transport.cjs');
test('récepteur Godot : même modèle après changements, refus et retrait complet de branche',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const t=createTransport(),dir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-transport-fixture-')),fixture=path.join(dir,'cases.json');let base=0;
 const cases=[{meta:{week:1,exportText:'temp'},clubLife:{market:{rows:[1,2]},press:{required:true}},preview:{value:2},live:{minute:2}},{meta:{week:1},clubLife:{market:{rows:[1,2]},press:{required:false}},live:null},{meta:{},clubLife:{},live:null}].map((model,i)=>{
  const response=t.encode({id:i+1,ok:i!==1,model},{version:1,base});base=response.transport.revision;return {response,expected:model};
 });
 fs.writeFileSync(fixture,JSON.stringify(cases));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--path',path.resolve(__dirname,'../native/godot'),'--script',path.join(__dirname,'godot-model-transport.gd')],{encoding:'utf8',timeout:30000,env:{...process.env,CD_TRANSPORT_CASES:fixture}});
 const log=(r.stdout||'')+(r.stderr||'');console.log(log);assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
