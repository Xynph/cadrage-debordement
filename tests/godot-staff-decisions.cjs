'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Staff, formation et décisions : interactions Windows natives et trois tailles',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(process.env.CD_STAFF_UI_ROOT||os.tmpdir(),'cd-staff-ui-'));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_STAFF_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-staff-decisions.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_STAFF_CAPTURES:directory},encoding:'utf8',windowsHide:true,timeout:180000});
 const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),text);console.log(text.trim());console.log('Preuves staff/décisions : '+directory);if(r.error)throw r.error;assert.equal(r.status,0,text);assert.doesNotMatch(text,/SCRIPT ERROR|Parse Error|ERROR:/);
});
