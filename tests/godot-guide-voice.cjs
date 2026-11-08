'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Gabi : couverture explicite, WAV exacts et cycle audio réel', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-guide-voice-'));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-guide-voice.gd')],{
  cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GUIDE_VOICE_TEST_DIR:directory},encoding:'utf8',windowsHide:true,timeout:30000});
 const output=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());
 if(r.error)throw r.error;assert.equal(r.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
