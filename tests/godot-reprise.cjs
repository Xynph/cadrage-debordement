'use strict';
// Reprise choisie : écran de création (départ de la partie) et décision de reprise, Godot réel.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Reprise : départ choisi à la création et décision de reprise dans la Préparation',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_REPRISE_UI_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-reprise-ui-'));fs.mkdirSync(output,{recursive:true});
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'oval-reprise-profile-'));
 const graphics=process.env.CD_REPRISE_UI_GRAPHICS==='1';
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','1920x1080']:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-reprise.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:300000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profile,CD_REPRISE_UI_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves reprise : '+output);
 if(result.error)throw result.error;
 assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
 fs.rmSync(profile,{recursive:true,force:true});
});
