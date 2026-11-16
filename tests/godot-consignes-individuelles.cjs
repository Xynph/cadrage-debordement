'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Tireurs et lanceur : listes par rôle, set_tactics et mise en garde de Gabi',{skip:!godot&&'SDK Godot requis'},()=>{
 const result=spawnSync(godot,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-consignes-individuelles.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());if(result.error)throw result.error;
 assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
