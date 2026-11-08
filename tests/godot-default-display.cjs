'use strict';
// Real project startup and preferences controls; graphical assertions require Windows.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-default-display : SDK Godot absent.');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-default-display-'));
const appData=path.join(directory,'AppData','Roaming'),localData=path.join(directory,'AppData','Local');
fs.mkdirSync(appData,{recursive:true});fs.mkdirSync(localData,{recursive:true});
const graphics=process.env.CD_DEFAULT_DISPLAY_GRAPHICS==='1';
const result=spawnSync(godot,[...(graphics?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--log-file',path.join(directory,'runtime.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-default-display.gd')],{env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_DEFAULT_DISPLAY_ARTIFACTS:directory},encoding:'utf8',windowsHide:true,timeout:90000});
const output=(result.stdout||'')+(result.stderr||'');
fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves affichage : '+directory);
if(result.error)throw result.error;
assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
const report=JSON.parse(fs.readFileSync(path.join(directory,'report.json'),'utf8'));
assert.equal(report.failures.length,0);
if(graphics)assert.equal(report.native_display,'Windows','La réception graphique exige le vrai DisplayServer Windows.');
