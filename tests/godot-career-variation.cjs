'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Création : case par défaut, clavier, choix conservé et véritable nouvelle carrière',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_VARIATION_UI_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-variation-ui-'));fs.mkdirSync(output,{recursive:true});
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'oval-variation-profile-'));
 const graphics=process.env.CD_VARIATION_UI_GRAPHICS==='1';
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-career-variation.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:240000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profile,CD_VARIATION_UI_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves variation : '+output);
 if(result.error)throw result.error;
 assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
 fs.rmSync(profile,{recursive:true,force:true});
});
