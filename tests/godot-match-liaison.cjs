'use strict';
// Liaison 3D entre deux temps forts contigus (native/godot/match_liaison.gd) : contiguïté, type,
// coupe franche si la mise en place est longue, vitesse réelle, aucun saut, déterminisme.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-liaison : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const result=spawnSync(godot,['--headless','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-liaison.gd')],{encoding:'utf8',windowsHide:true,timeout:300000,env:{...process.env,CD_GODOT_SELF_TEST:'0'}});
const output=(result.stdout||'')+(result.stderr||'');console.log(output);
if(result.error)throw result.error;
assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
const m=output.match(/Liaison : (\d+) contrôles ; 0 échec/);assert.ok(m&&Number(m[1])>=40,'contrôles de la liaison');
