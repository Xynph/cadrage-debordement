'use strict';
// Accord en nombre des libellés (« 1 saison », jamais « 1 saison(s) ») : voir tests/godot-accord-libelles.gd.
const fs=require('node:fs'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-accord-libelles : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-accord-libelles.gd')],{env:{...process.env,CD_GODOT_SELF_TEST:'0'},encoding:'utf8',windowsHide:true,timeout:120000});
const output=(result.stdout||'')+(result.stderr||'');
process.stdout.write(output);
if(result.status!==0||/SCRIPT ERROR|Parse Error/.test(output)){console.error('godot-accord-libelles : échec');process.exit(1);}
console.log('godot-accord-libelles : OK');
