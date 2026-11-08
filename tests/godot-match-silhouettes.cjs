'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
test('Native match: original rugby kit, shared morphology and unchanged rig', {skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const proof=process.env.CD_MATCH_SILHOUETTES_PROOF||fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-silhouettes-'));
 fs.mkdirSync(proof,{recursive:true});
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--path',project,'--script',path.resolve(__dirname,'godot-match-silhouettes.gd')],{encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'silhouettes-headless.log'),output);console.log(output);console.log('Proof: '+proof);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 const result=output.match(/MATCH_SILHOUETTES_CHECKS (.+)/);assert.ok(result,'Silhouette fixture must complete');
 const metrics=JSON.parse(result[1]);assert.equal(metrics.failed,0);assert.equal(metrics.renderer,'headless');
});
