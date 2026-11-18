'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
test('Native match: bound 3-4-1 scrums, scrum exit and lineout formation', {skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const proof=process.env.CD_MATCH_FORMATIONS_PROOF||fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-formations-'));
 fs.mkdirSync(proof,{recursive:true});
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--audio-driver','Dummy','--path',project,'--script',path.resolve(__dirname,'godot-match-formations.gd')],{encoding:'utf8',windowsHide:true,timeout:90000});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'formations-headless.log'),output);console.log(output);console.log('Proof: '+proof);
 assert.equal(run.status,0,output);assert.match(output,/MATCH_FORMATIONS_OK/);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
