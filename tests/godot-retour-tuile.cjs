'use strict';
// Retour visuel commun des tuiles (option A) et rayures alignees sur l'Effectif : scene nue, sans carriere.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-retour-tuile : SDK Godot absent.');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-retour-tuile-'));
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(directory,'profil')};
const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--log-file',path.join(directory,'runtime.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-retour-tuile.gd')],{env,encoding:'utf8',windowsHide:true,timeout:240000});
const output=(result.stdout||'')+(result.stderr||'');
fs.writeFileSync(path.join(directory,'godot.log'),output);
console.log(output);
if(result.error)throw result.error;
assert.equal(result.status,0,output);
assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
assert.match(output,/RETOUR_TUILE checks=\d+ failures=0/);
