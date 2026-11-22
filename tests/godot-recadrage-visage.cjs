'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Photos de pack recadrées sur le visage dans les cases carrées',{skip:!godot&&'SDK Godot requis'},()=>{
 const profil=fs.mkdtempSync(path.join(os.tmpdir(),'cd-recadrage-'));
 const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--path','native/godot','--script',path.resolve(__dirname,'godot-recadrage-visage.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_DATA_DIR:profil},encoding:'utf8',timeout:60000,windowsHide:true});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());
 fs.rmSync(profil,{recursive:true,force:true});
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);assert.match(output,/RECADRAGE VISAGE : \d+ contrôles ; 0 échec/);
});
