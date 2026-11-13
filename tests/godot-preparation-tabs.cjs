'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Real main.tscn, worker and isolated profile. No season simulation.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-preparation-tabs : SDK Godot absent.');process.exit(0);}
assert.ok(fs.existsSync(path.join(__dirname,'../native/godot/ui/preparation_view.gd')),'Préparation doit avoir ses vrais sous-onglets');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-preparation-tabs-'));
const appData=path.join(directory,'AppData','Roaming'),localData=path.join(directory,'AppData','Local');fs.mkdirSync(appData,{recursive:true});fs.mkdirSync(localData,{recursive:true});
const checkpoint=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/france-long-career-s6.json.gz')))).checkpoint.save;
fs.writeFileSync(path.join(directory,'career.json'),JSON.stringify(checkpoint));
const project=process.env.CD_PREPARATION_PROJECT||path.resolve(__dirname,'../native/godot');
const result=spawnSync(godot,[...(process.env.CD_PREPARATION_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--log-file',path.join(directory,'runtime.log'),'--path',project,'--script',path.resolve(__dirname,'godot-preparation-tabs.gd')],{env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_PREPARATION_ARTIFACTS:directory},encoding:'utf8',windowsHide:true,timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves Préparation : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
