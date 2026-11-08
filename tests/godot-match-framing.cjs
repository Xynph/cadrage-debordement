'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
test('Native match: follow framing, full tactical view and original contrasting kits', {skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const proof=process.env.CD_MATCH_FRAMING_PROOF||fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-framing-'));
 fs.mkdirSync(proof,{recursive:true});
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-framing.gd')],{encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'framing-headless.log'),output);console.log(output);console.log('Proof: '+proof);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
