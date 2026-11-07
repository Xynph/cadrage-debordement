'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Coach intégré : espace réservé, toutes routes et commandes accessibles sans mutation', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-guide-integrated-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_GUIDE_INTEGRATION_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-guide-integration.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_GUIDE_INTEGRATION_CAPTURES:directory},encoding:'utf8',windowsHide:true,timeout:150000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());console.log('Preuves raccord : '+directory);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
