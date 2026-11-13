'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {collect}=require('../tools/qa/effective-training-receipt.cjs');
const sdk=process.env.CD_GODOT_EXECUTABLE;
if(!sdk){console.log('SKIP effective-training-receipt : SDK requis ; aucun reçu Godot qualifié.');process.exit(0);}
const output=process.env.CD_EFFECTIVE_TRAINING_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'rg27-effective-training-proof-'));fs.mkdirSync(output,{recursive:true});
const fixture=path.join(output,'worker-cases.json');
if(process.env.CD_EFFECTIVE_TRAINING_REUSE_CASES)fs.copyFileSync(process.env.CD_EFFECTIVE_TRAINING_REUSE_CASES,fixture);else collect(fixture);
const result=spawnSync(sdk,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-effective-training-receipt.gd')],
 {encoding:'utf8',timeout:150000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_EFFECTIVE_TRAINING_CASES:fixture,CD_EFFECTIVE_TRAINING_OUTPUT:output}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves mode réellement appliqué : '+output);
if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
