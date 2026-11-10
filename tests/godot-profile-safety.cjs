'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Copies de sécurité : lecture, annulation, reprise et suppression dans la vraie application', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const output=process.env.CD_SAFETY_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-safety-ui-'));
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'oval-safety-profile-'));fs.mkdirSync(output,{recursive:true});
 const dimensions=process.env.QA_RESOLUTION||'2560x1440';assert.equal(dimensions,'2560x1440','Cette recette cible exclusivement le 1440p.');
 const graphics=process.env.CD_SAFETY_GRAPHICS==='1';
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution',dimensions]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-profile-safety.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profile,CD_SAFETY_OUTPUT:output,QA_RESOLUTION:dimensions},encoding:'utf8',timeout:210000});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves copies : '+output);
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
