'use strict';
// Real main.tscn, worker and isolated profile. Mode Monde : vraie carrière world-champ (club 5), sans simulation de saison.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const M=require('./helpers/carriere-monde.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-preparation-tabs : SDK Godot absent.');process.exit(0);}
assert.ok(fs.existsSync(path.join(__dirname,'../native/godot/ui/preparation_view.gd')),'Préparation doit avoir ses vrais sous-onglets');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-preparation-tabs-'));
const appData=path.join(directory,'AppData','Roaming'),localData=path.join(directory,'AppData','Local');fs.mkdirSync(appData,{recursive:true});fs.mkdirSync(localData,{recursive:true});
{const jeu=M.ouvrir({dataDir:fs.mkdtempSync(path.join(directory,'monde-')),mandatoryPress:false});
 try{
  // Avance jusqu'au premier jour où le dossier adverse est rempli (au plus tard le jour du match).
  let m=M.creer(jeu,5);
  for(let j=0;j<150;j++){m=jeu.regler(m);const p=m.decisions?.preparation;if((p&&Object.keys(p).length)||m.meta.calendarCadence?.matchReady)break;m=jeu.call('advance_day',{fromDate:m.meta.calendarToday});}
  assert.ok(m.decisions?.preparation&&Object.keys(m.decisions.preparation).length,'dossier adverse rempli avant le match');
  fs.writeFileSync(path.join(directory,'career.json'),jeu.call('export').meta.exportText);}finally{jeu.fermer();fs.rmSync(jeu.dataDir,{recursive:true,force:true});}}
const project=process.env.CD_PREPARATION_PROJECT||path.resolve(__dirname,'../native/godot');
const result=spawnSync(godot,[...(process.env.CD_PREPARATION_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--log-file',path.join(directory,'runtime.log'),'--path',project,'--script',path.resolve(__dirname,'godot-preparation-tabs.gd')],{env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_PREPARATION_ARTIFACTS:directory},encoding:'utf8',windowsHide:true,timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves Préparation : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
