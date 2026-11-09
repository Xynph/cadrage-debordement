'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
test('Godot mentorat : activation, choix du jeune et commande contextualisée',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-staff-mentoring-ui-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-staff-mentoring.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,XDG_DATA_HOME:path.join(dir,'data'),XDG_CONFIG_HOME:path.join(dir,'config'),XDG_CACHE_HOME:path.join(dir,'cache')},encoding:'utf8',timeout:30000});
 const output=(result.stdout||'')+(result.stderr||'');if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/STAFF_MENTORING_UI_PASS/);
});
