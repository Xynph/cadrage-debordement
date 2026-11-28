'use strict';
// Entrée animée des pages dessinées (Bureau) : voir tests/godot-entree-page.gd.
const fs=require('node:fs'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-entree-page : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-entree-page.gd')],{env:{...process.env,CD_GODOT_SELF_TEST:'0'},encoding:'utf8',windowsHide:true,timeout:120000});
const output=(result.stdout||'')+(result.stderr||'');
process.stdout.write(output);
if(result.status!==0||/SCRIPT ERROR|Parse Error/.test(output)){console.error('godot-entree-page : échec');process.exit(1);}
console.log('godot-entree-page : OK');
