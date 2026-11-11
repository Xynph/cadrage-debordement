'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Connaissances UI : aucun potentiel exact, niveaux étrangers bornés et tris visibles',{skip:!godot&&'SDK Godot requis'},()=>{
 const result=spawnSync(godot,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-player-knowledge-text.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());if(result.error)throw result.error;
 assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
