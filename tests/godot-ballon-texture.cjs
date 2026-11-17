'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
const assert=require('node:assert/strict');
// Aucun avertissement « invalid UID » à l'ouverture du ballon (texture embarquée, PNG extrait supprimé de la chaîne).
test('Ballon du Bureau : texture embarquée et aucun UID invalide dans le journal Godot', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-ballon-texture-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-ballon-texture.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:240000,env:{...process.env,CD_GODOT_DATA_DIR:root}});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),output);console.log(output.trim());
 if(result.error)throw result.error;assert.equal(result.status,0,output);
 assert.doesNotMatch(output,/invalid UID|SCRIPT ERROR|Parse Error|ERROR:/);
});
