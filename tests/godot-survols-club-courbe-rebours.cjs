'use strict';
// Survols du 21/11/2026 (mini-carte club, mini-courbes, compte à rebours) dans le vrai main.tscn, worker réel et profil isolé.
// Mode Monde : carrière world-champ (club 5), trois matchs joués (relevés de trésorerie, de moral et de condition).
// CD_SURVOLS_EXPORT : carrière exportée à reprendre au lieu d'en jouer une ; CD_SURVOLS_GRAPHICS=1 + CD_SURVOLS_CAPTURES :
// captures 2560 et 1920.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const M=require('./helpers/carriere-monde.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-survols-club-courbe-rebours : SDK Godot absent.');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-survols-'));
const appData=path.join(directory,'AppData','Roaming'),localData=path.join(directory,'AppData','Local');fs.mkdirSync(appData,{recursive:true});fs.mkdirSync(localData,{recursive:true});
if(process.env.CD_SURVOLS_EXPORT)fs.copyFileSync(process.env.CD_SURVOLS_EXPORT,path.join(directory,'career.json'));
else{const jeu=M.ouvrir({dataDir:fs.mkdtempSync(path.join(directory,'monde-')),mandatoryPress:false});
 try{
  let m=M.creer(jeu,5);
  m=M.jouer(jeu,m,3);
  assert.ok(m.groupHistory.length>=2,'relevés du groupe');
  fs.writeFileSync(path.join(directory,'career.json'),jeu.call('export').meta.exportText);}finally{jeu.fermer();fs.rmSync(jeu.dataDir,{recursive:true,force:true});}}
const graphique=process.env.CD_SURVOLS_GRAPHICS==='1';
const result=spawnSync(godot,[...(graphique?['--rendering-driver','opengl3','--windowed','--resolution','2560x1440']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--log-file',path.join(directory,'runtime.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-survols-club-courbe-rebours.gd')],{env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_SURVOLS_ARTIFACTS:directory,CD_SURVOLS_CAPTURES:graphique?(process.env.CD_SURVOLS_CAPTURES||''):''},encoding:'utf8',windowsHide:true,timeout:400000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves survols : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/SURVOLS checks=\d+ failures=0/);
