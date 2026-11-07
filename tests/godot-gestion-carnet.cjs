'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
test('Gestion carnet : saisie clavier, continuité et comparaison sans mutation',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-gestion-carnet-'));
 fs.writeFileSync(path.join(root,'archive-fixture.json'),require('node:zlib').gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/roster-foundation-v1-s2.json.gz'))));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_GESTION_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-gestion-carnet.gd')],{env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:root,CD_ARCHIVE_FIXTURE:path.join(root,'archive-fixture.json'),CD_GESTION_CAPTURES:process.env.CD_GESTION_CAPTURES||root},encoding:'utf8',windowsHide:true,timeout:180000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),output);console.log(output.trim());console.log('Preuves gestion : '+root);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
