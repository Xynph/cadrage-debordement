'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
test('Brouillon jeunes : annulation, refus disque et validation réelle', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-youth-draft-'));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'deepen-youth-draft.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'profile'),XDG_DATA_HOME:path.join(dir,'data'),XDG_CONFIG_HOME:path.join(dir,'config'),XDG_CACHE_HOME:path.join(dir,'cache')}});
 const out=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),out);console.log(out);console.log('Preuves brouillon jeunes : '+dir);if(r.error)throw r.error;assert.equal(r.status,0,out);assert.doesNotMatch(out,/SCRIPT ERROR|Parse Error|ERROR:/);
});
