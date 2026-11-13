'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
const project=process.env.CD_SEMANTIC_PROJECT||path.resolve(__dirname,'../native/godot');
const script=process.env.CD_SEMANTIC_SCRIPT||path.resolve(__dirname,'godot-data-semantics.gd');
test('Native UI: semantic standings retain public values, missing data and contrast', {skip:!godot&&'Godot SDK required'},()=>{
 const proof=process.env.CD_SEMANTIC_PROOF||fs.mkdtempSync(path.join(os.tmpdir(),'cd-semantic-data-'));
 fs.mkdirSync(proof,{recursive:true});
 const run=spawnSync(godot,['--headless','--max-fps','120','--path',project,'--script',script],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_SEMANTIC_PROOF:proof,CD_SEMANTIC_CAPTURE:'0',CD_SEMANTIC_APP:'0'}});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'semantic-headless.log'),output);console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 const match=output.match(/SEMANTIC_DATA_CHECKS (.+)/);assert.ok(match,'Semantic fixture must complete');
 const result=JSON.parse(match[1]);assert.deepEqual(result.failures,[]);assert.equal(result.metrics.length,4);assert.equal(result.display,'headless');
});


test('Native UI: real Bureau and standings preserve career, RNG and disk at 720p/1440p', {skip:!godot&&'Godot SDK required'},()=>{
 const proof=fs.mkdtempSync(path.join(process.env.CD_SEMANTIC_TEMP||os.tmpdir(),'cd-semantic-app-'));
 const run=spawnSync(godot,[...(process.env.CD_SEMANTIC_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path',project,'--script',script],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(proof,'profile'),CD_SEMANTIC_PROOF:proof,CD_SEMANTIC_APP:'1',CD_SEMANTIC_CAPTURE:process.env.CD_SEMANTIC_GRAPHICS==='1'?'1':'0'}});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'semantic-real-app.log'),output);console.log(output);console.log('Preuves vraies pages : '+proof);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 const match=output.match(/SEMANTIC_APP_CHECKS (.+)/);assert.ok(match,'Real pages fixture must complete');
 const result=JSON.parse(match[1]);assert.deepEqual(result.failures,[]);assert.equal(result.metrics.length,2);
});
