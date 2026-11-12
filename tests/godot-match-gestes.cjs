'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs');
const {sequence}=require('./godot-match-gestes-scenes.cjs');
const fixture=path.resolve(__dirname,'fixtures/match-gestes-sequence.json');
test('Gestes de match : la séquence rejouée est exactement celle que produit le moteur',()=>{
 // Régénérer : node tests/godot-match-gestes-scenes.cjs > tests/fixtures/match-gestes-sequence.json
 assert.deepEqual(JSON.parse(fs.readFileSync(fixture,'utf8')),JSON.parse(JSON.stringify(sequence())));
});
test('Gestes de match : touche portée, ballon porté et essai aplati suivent les faits du moteur',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};delete env.CD_MATCH_GESTES;
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-gestes.gd')],{encoding:'utf8',windowsHide:true,timeout:120000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_GESTES_CHECKS \d+ failures=0/);
});
