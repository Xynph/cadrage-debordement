'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-art-direction.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
// Run each explicit case in its own Node invocation under the unchanged 180s gate.
// The four cases preserve all three route/dialog matrices and the match sequence.
const scenario=process.env.CD_ART_DIRECTION_CASE||'';
assert.ok(['','routes-1280','routes-1600','routes-1920','progression'].includes(scenario),'Unknown CD_ART_DIRECTION_CASE');
const dir=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-art-direction-'));
const result=spawnSync(godot,['--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-art-direction.gd')],{windowsHide:true,encoding:'utf8',timeout:540000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'profile'),CD_ART_DIRECTION_DIR:dir}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),log);console.log(log);console.log('Réception artistique : '+dir);
if(result.error)throw result.error;
assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
