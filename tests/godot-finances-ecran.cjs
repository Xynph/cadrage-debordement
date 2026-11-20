'use strict';
// Real main.tscn, worker and isolated profile. Mode Monde : vraie carrière world-champ (club 5), deux semaines jouées.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const M=require('./helpers/carriere-monde.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-finances-ecran : SDK Godot absent.');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-finances-ecran-'));
const appData=path.join(directory,'AppData','Roaming'),localData=path.join(directory,'AppData','Local');fs.mkdirSync(appData,{recursive:true});fs.mkdirSync(localData,{recursive:true});
{const jeu=M.ouvrir({dataDir:fs.mkdtempSync(path.join(directory,'monde-')),mandatoryPress:false});
 try{
  let m=M.creer(jeu,5);
  for(let j=0;j<14;j++){m=jeu.regler(m);m=jeu.call('advance_day',{fromDate:m.meta.calendarToday});}
  fs.writeFileSync(path.join(directory,'career.json'),jeu.call('export').meta.exportText);}finally{jeu.fermer();fs.rmSync(jeu.dataDir,{recursive:true,force:true});}}
const project=process.env.CD_FINANCES_PROJECT||path.resolve(__dirname,'../native/godot');
const result=spawnSync(godot,[...(process.env.CD_FINANCES_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--log-file',path.join(directory,'runtime.log'),'--path',project,'--script',path.resolve(__dirname,'godot-finances-ecran.gd')],{env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_FINANCES_ARTIFACTS:directory},encoding:'utf8',windowsHide:true,timeout:300000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves Finances : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
