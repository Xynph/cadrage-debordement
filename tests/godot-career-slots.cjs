'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Mes carrières : deux carrières Monde, bascule et suppression confirmée dans la vraie application', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const output=fs.mkdtempSync(path.join(os.tmpdir(),'cd-slots-ui-')),profile=fs.mkdtempSync(path.join(os.tmpdir(),'cd-slots-profile-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-career-slots.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.env.CD_NODE_EXECUTABLE||process.execPath,CD_GODOT_DATA_DIR:profile,CD_SLOTS_OUTPUT:output},encoding:'utf8',timeout:420000});
 const log=(result.stdout||'')+(result.stderr||'');console.log(log.trim().split('\n').slice(-15).join('\n'));
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error/);
 assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
 fs.rmSync(profile,{recursive:true,force:true});
});
