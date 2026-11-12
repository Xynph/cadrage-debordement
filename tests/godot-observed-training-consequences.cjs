'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {collect}=require('../tools/qa/observed-training-consequences.cjs');
const sdk=process.env.CD_GODOT_EXECUTABLE;
if(!sdk){console.log('SKIP observed-training-consequences : SDK Godot requis, aucune réception du reçu.');process.exit(0);}
const output=process.env.CD_OBSERVED_TRAINING_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'rg27-observed-training-proof-'));fs.mkdirSync(output,{recursive:true});
const fixture=path.join(output,'worker-cases.json');
if(process.env.CD_OBSERVED_TRAINING_REUSE_CASES)fs.copyFileSync(process.env.CD_OBSERVED_TRAINING_REUSE_CASES,fixture);else collect(fixture);
const result=spawnSync(sdk,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-observed-training-consequences.gd')],
 {encoding:'utf8',timeout:150000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_OBSERVED_TRAINING_CASES:fixture,CD_OBSERVED_TRAINING_OUTPUT:output}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves conséquences observées : '+output);
if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
