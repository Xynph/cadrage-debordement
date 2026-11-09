'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Carrières staff et vivier : interactions réelles dans Godot',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-lifecycle-ui-'));
 const graphics=process.env.CD_LIFECYCLE_GRAPHICS==='1';
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--audio-driver','Dummy']:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-lifecycle.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_LIFECYCLE_CAPTURES:directory},encoding:'utf8',windowsHide:true,timeout:180000});
 const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),text);console.log(text.trim());console.log('Preuves lifecycle : '+directory);if(r.error)throw r.error;assert.equal(r.status,0,text);assert.doesNotMatch(text,/SCRIPT ERROR|Parse Error|ERROR:/);
});
