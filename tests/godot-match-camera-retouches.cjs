'use strict';
// Retouches de caméra du match 3D : inclinaison plafonnée près de la touche, essai en coin sans tribune,
// poteaux contournés par la caméra au contact, cadrage adaptatif hors temps fort.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
test('Caméra du match : vue de 3/4 près de la touche, coin sans tribune, poteaux contournés, cadrage qui suit les joueurs',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-camera-retouches.gd')],{encoding:'utf8',windowsHide:true,timeout:180000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_CAMERA_RETOUCHES_CHECKS \d+ failures=0/);
});
