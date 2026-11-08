'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),path=require('node:path');
test('Build vocal : couverture explicite et refus des clips obsolètes/corrompus',()=>{
 const python=process.env.CD_PYTHON_EXECUTABLE||(process.platform==='win32'?'python':'python3');
 const result=spawnSync(python,[path.join(__dirname,'godot-voice-assets.py')],{encoding:'utf8',windowsHide:true,timeout:30000});
 if(result.error)throw result.error;
 console.log((result.stdout||'')+(result.stderr||''));assert.equal(result.status,0);
});
