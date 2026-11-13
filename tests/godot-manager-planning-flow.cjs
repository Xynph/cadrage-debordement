'use strict';
process.env.CD_MODES_HERITES='1'; // Legacy fixtures; production keeps World-only mode.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
test('atelier raccordé : vrais menus, vrai pont et vrai worker',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const graphics=process.env.CD_MANAGER_PLANNING_GRAPHICS==='1',profile=fs.mkdtempSync(path.join(os.tmpdir(),'oval-planner-godot-'));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed']:['--headless']),'--audio-driver','Dummy','--max-fps','30','--path',path.resolve(__dirname,'../native/godot'),'--script',path.join(__dirname,'godot-manager-planning-flow.gd')],{encoding:'utf8',timeout:180000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_SEED:'27',CD_GODOT_DATA_DIR:profile}});
 const log=(r.stdout||'')+(r.stderr||'');console.log(log);console.log('Profil de recette : '+profile);assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed/);
});
