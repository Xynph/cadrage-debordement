'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Relève : détection, suivi persistant et plans des jeunes dans le vrai client',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-youth-scout-ui-')),graphics=process.env.CD_YOUTH_SCOUT_GRAPHICS==='1';
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--audio-driver','Dummy']:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-youth-scout-ui.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_YOUTH_SCOUT_CAPTURES:directory},encoding:'utf8',timeout:270000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());console.log('Preuves relève : '+directory);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
