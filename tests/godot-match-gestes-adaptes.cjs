'use strict';
// Gestes adaptés (bibliothèque CD_MATCH_ANIMATIONS) : lancer, ballon porté, essai, joie, déception,
// pénalité, réception, plaqué et relevé ; repli procédural sans bibliothèque.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
test('Gestes adaptés : enchaînés sur les faits du moteur, repli procédural sans bibliothèque',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-gestes-adaptes.gd')],{encoding:'utf8',windowsHide:true,timeout:240000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_GESTES_ADAPTES_CHECKS \d+ failures=0/);
});
