'use strict';
// Vraie interface + vrai moteur. Le match en temps forts est le mode de base : sans
// aucune variable, le match enchaîne temps fort → écran intermédiaire → temps fort.
// CD_MATCH_TEMPS_FORTS=0 rend le direct d'origine, sans régie.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),{context}=require('./harness.cjs');
const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-temps-forts : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-temps-forts-'));
const source=context();
source.run('start(0);beginMatch()');
fs.writeFileSync(path.join(directory,'live.json'),source.run('JSON.stringify(createSaveDocument())'));
// Parcours du joueur : une vraie carrière arrêtée à la causerie d'avant-match (causeries et débrief actifs).
{
 const dataDir=fs.mkdtempSync(path.join(directory,'carriere-'));
 const bridge=createBridge({dataDir,seed:7,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true});
 let id=0;const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 settleClubMeetings(call('new_career',{club:0}),call);
 assert.equal(call('begin_match').clubLife.matchTalks.scene.phase,'pre');
 fs.writeFileSync(path.join(directory,'causerie.json'),call('export').meta.exportText);
 bridge.close?.();fs.rmSync(dataDir,{recursive:true,force:true});
}
function run(mode,dossier=mode){
 const data=path.join(directory,dossier,'PrototypeGodot');
 const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:data,CD_MATCH_TEMPS_FORTS_ARTIFACTS:directory,CD_MATCH_TEMPS_FORTS_MODE:mode,CD_GODOT_SEED:'11'}; // même graine, même match
 delete env.CD_MATCH_TEMPS_FORTS;delete env.CD_MATCH_TEMPS_FORTS_NIVEAU;delete env.CD_MATCH_TEMPS_FORTS_HORLOGE;delete env.CD_MATCH_TEMPS_FORTS_VITESSE;delete env.CD_MATCH_GESTES;
 // Repli explicite : le direct d'origine.
 if(mode==='inactif')env.CD_MATCH_TEMPS_FORTS='0';
 // Mode de base : aucune variable de mode. Horloge et vitesse ne servent qu'à la durée du test.
 if(mode==='defaut')Object.assign(env,{CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4',CD_GODOT_SEED:'7'});
 if(mode==='reprise')Object.assign(env,{CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_GODOT_SEED:'7'});
 if(mode==='actif')Object.assign(env,{CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4'});
 // Temps forts et gestes ensemble, à vitesse de jeu : vingt minutes de match sans que rien ne se fige.
 if(mode==='gestes')Object.assign(env,{CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_GESTES:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_GODOT_SEED:'7'});
 const result=spawnSync(godot,['--headless','--max-fps','60','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-temps-forts.gd')],{env,encoding:'utf8',windowsHide:true,timeout:600000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot-'+mode+'.log'),output);console.log(output);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 return JSON.parse(fs.readFileSync(path.join(directory,'report-'+mode+'.json'),'utf8'));
}
// CD_MATCH_TEMPS_FORTS_MODES=defaut,reprise… ne rejoue que les modes cités (mise au point) ; « reprise » suit « gestes ».
const voulus=(process.env.CD_MATCH_TEMPS_FORTS_MODES||'').split(',').filter(Boolean),veut=mode=>!voulus.length||voulus.includes(mode);
const bilan=[];
if(veut('inactif')){
 const sans=run('inactif');
 assert.deepEqual(sans.failures,[]);assert.ok(sans.checks>=4);bilan.push('repli '+sans.checks);
}
if(veut('actif')){
 const avec=run('actif');
 assert.deepEqual(avec.failures,[]);assert.ok(avec.checks>=25,'contrôles : '+avec.checks);
 const ordre=avec.suivi.map(e=>e.evenement);
 const premier=ordre.indexOf('temps_fort'),entre=ordre.indexOf('intermediaire',premier+1),second=ordre.indexOf('temps_fort',entre+1);
 assert.ok(premier>=0&&entre>premier&&second>entre,'temps fort → écran intermédiaire → temps fort : '+ordre.join(', '));
 bilan.push('actif '+avec.checks+' ('+ordre.filter(e=>e==='temps_fort').length+' temps forts)');
}
if(veut('gestes')){
 const gestes=run('gestes');
 assert.deepEqual(gestes.failures,[]);assert.ok(gestes.checks>=10,'contrôles avec les gestes : '+gestes.checks);
 assert.ok(gestes.suivi.filter(e=>e.evenement==='temps_fort').length>=4&&!gestes.suivi.some(e=>e.evenement==='echeance'),'temps forts et gestes : '+JSON.stringify(gestes.suivi.map(e=>e.evenement)));
 bilan.push('gestes '+gestes.checks);
}
if(veut('reprise')){
 // Le match laissé en pause par le mode « gestes » est repris par une nouvelle session, sans variable.
 assert.ok(fs.existsSync(path.join(directory,'gestes','PrototypeGodot')),'« reprise » suit « gestes »');
 const reprise=run('reprise','gestes');
 assert.deepEqual(reprise.failures,[]);assert.ok(reprise.checks>=15,'contrôles à la reprise : '+reprise.checks);
 assert.ok(reprise.suivi.some(e=>e.evenement==='reprise')&&reprise.suivi.some(e=>e.evenement==='delegation'),'reprise puis délégation : '+JSON.stringify(reprise.suivi.map(e=>e.evenement)));
 bilan.push('reprise '+reprise.checks);
}
if(veut('defaut')){
 const defaut=run('defaut');
 assert.deepEqual(defaut.failures,[]);assert.ok(defaut.checks>=35,'contrôles du parcours par défaut : '+defaut.checks);
 assert.ok(defaut.suivi.filter(e=>e.evenement==='temps_fort').length>=4,'temps forts du parcours par défaut : '+JSON.stringify(defaut.suivi.map(e=>e.evenement)));
 bilan.push('défaut '+defaut.checks);
}
console.log('Preuves temps forts : '+directory+' · contrôles : '+bilan.join(' · '));
