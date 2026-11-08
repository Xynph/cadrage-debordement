'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
test('Native match: carrier ball contact and thirty actors', {skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const proof=fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-presentation-'));
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-presentation.gd')],{encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'godot.log'),output);console.log(output);console.log('Proof: '+proof);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
