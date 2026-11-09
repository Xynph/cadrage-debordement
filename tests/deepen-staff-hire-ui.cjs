'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),os=require('node:os');
test('Staff réel : recrutement et prolongation avec durée conservée après refus disque',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-staff-real-ui-')),project=process.env.CD_STAFF_REAL_ROOT||path.resolve(__dirname,'..');
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--max-fps','120','--path',path.join(project,'native/godot'),'--script',path.resolve(__dirname,'deepen-staff-hire-ui.gd')],{cwd:project,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'PrototypeGodot'),XDG_DATA_HOME:path.join(dir,'data'),XDG_CONFIG_HOME:path.join(dir,'config'),XDG_CACHE_HOME:path.join(dir,'cache')},encoding:'utf8',timeout:180000});
 const output=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output.trim());console.log('Preuve staff : '+dir);if(r.error)throw r.error;assert.equal(r.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/DEEPEN_STAFF_HIRE_UI: .* 0 échec/);
});
