'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Portraits des listes longues : chargement progressif identique à l’immédiat, cache d’un groupe entier',{skip:!godot&&'SDK Godot requis'},()=>{
 const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--path','native/godot','--script',path.resolve(__dirname,'godot-portraits-progressifs.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:60000});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
