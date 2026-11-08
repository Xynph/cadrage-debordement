'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-club-life-strategy.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-strategy-ui-'));
const result=spawnSync(godot,[...(process.env.CD_STRATEGY_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-club-life-strategy.gd')],{windowsHide:true,encoding:'utf8',timeout:240000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'PrototypeGodot'),CD_STRATEGY_ARTIFACTS:root}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves stratégie : '+root);
if(result.error)throw result.error;
assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
