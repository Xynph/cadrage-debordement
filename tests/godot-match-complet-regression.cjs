'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Match complet : porteur hors alignement et rapport après libération des régies',{skip:!godot&&'Godot SDK required'},()=>{
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-regression-'));
 try{
  const run=spawnSync(godot,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-complet-regression.gd')],{encoding:'utf8',timeout:180000,env:{...process.env,XDG_DATA_HOME:profile}});
  const output=(run.stdout||'')+(run.stderr||'');console.log(output);
  assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
  assert.match(output,/MATCH_COMPLET_REGRESSION_CHECKS \d+ failures=0/);
 }finally{fs.rmSync(profile,{recursive:true,force:true});}
});
