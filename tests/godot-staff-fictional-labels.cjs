'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
test('Staff characters are presented without origin warnings', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-staff-labels-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.join(__dirname,'godot-staff-fictional-labels.gd')],{env:{...process.env,XDG_DATA_HOME:path.join(dir,'data'),XDG_CONFIG_HOME:path.join(dir,'config'),XDG_CACHE_HOME:path.join(dir,'cache')},encoding:'utf8',timeout:30000});
 const output=(result.stdout||'')+(result.stderr||'');
 fs.writeFileSync(path.join(dir,'godot.log'),output);
 if(result.error)throw result.error;
 assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
 assert.match(output,/STAFF_FICTIONAL_LABELS.*"failures":\[\]/);
});
