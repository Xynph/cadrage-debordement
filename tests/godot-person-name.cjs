'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const path=require('node:path'),{spawnSync}=require('node:child_process');
test('Patronymes de plusieurs mots conservés dans les feuilles de match',{
  skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis',
},()=>{
  const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--path','native/godot','--script',path.resolve(__dirname,'godot-person-name.gd')],{
    cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:120000,
  });
  const log=(result.stdout||'')+(result.stderr||'');console.log(log.trim());
  if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|FAIL:/);
  assert.match(log,/16 cas, 0 échec/);
});
