'use strict';
// Grands moments du match 3D : bandeau « ESSAI » (marqueur, équipe), ralenti puis image tenue avant la
// transformation, plan large et sortie des joueurs vers le tunnel à la mi-temps et en fin de match.
// 1) logique et vue 3D sans moteur (godot-match-grands-moments.gd, rapide) ;
// 2) parcours réel d'une carrière Monde (godot-match-temps-forts.gd, mode « grands_moments ») : premier
//    essai joué en 3D, mi-temps (plan large, marche, puis causerie), fin de match (sortie, puis débrief).
//    CD_GRANDS_MOMENTS_PARCOURS=0 ne lance que la première partie (mise au point).
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-grands-moments : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
{
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU','CD_MATCH_SORTIE'])delete env[name];
 const run=spawnSync(godot,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-grands-moments.gd')],{encoding:'utf8',windowsHide:true,timeout:180000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_GRANDS_MOMENTS_CHECKS \d+ failures=0/);
}
if(process.env.CD_GRANDS_MOMENTS_PARCOURS==='0'){console.log('Grands moments : parcours Monde non lancé (CD_GRANDS_MOMENTS_PARCOURS=0).');process.exit(0);}
const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-grands-moments-'));
{
 // Carrière Monde arrêtée à la causerie d'avant-match (même préparation que godot-match-score-essai.cjs).
 const dataDir=fs.mkdtempSync(path.join(directory,'carriere-'));
 const bridge=createBridge({dataDir,seed:7,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true});
 let id=0;const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 let model=call('new_career',{mode:'world-champ',club:0});
 for(let day=0;day<120;day++){model=settleClubMeetings(model,call);if(model.meta.calendarCadence?.matchReady)break;model=call('advance_day',{fromDate:model.meta.calendarToday});}
 model=settleClubMeetings(model,call);model=call('auto_lineup');if(!model.selection?.valid)call('promote_cover',{confirmed:true});
 // Pas de reprise en plein match (décision du 16/11/2026) : export le jour du match, le test lance begin_match après l'import.
 fs.writeFileSync(path.join(directory,'monde.json'),call('export').meta.exportText);
 bridge.close?.();fs.rmSync(dataDir,{recursive:true,force:true});
}
// Horloge éclair et temps forts ×4 : seule la durée du test change (sortie et moment d'essai suivent la vitesse).
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'grands_moments','PrototypeGodot'),CD_MATCH_TEMPS_FORTS_ARTIFACTS:directory,
 CD_MATCH_TEMPS_FORTS_MODE:'grands_moments',CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4',CD_MATCH_TEMPS_FORTS_NIVEAU:'cles',CD_GODOT_SEED:process.env.CD_GRANDS_MOMENTS_GRAINE||'3'};
for(const name of ['CD_MATCH_GESTES','CD_MATCH_CHOREGRAPHE','CD_MATCH_TEMPS_FORTS_ENTRACTE','CD_MATCH_SORTIE'])delete env[name];
const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','60','--path',project,'--script',path.resolve(__dirname,'godot-match-temps-forts.gd')],{env,encoding:'utf8',windowsHide:true,timeout:1500000});
const output=(result.stdout||'')+(result.stderr||'');console.log(output);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
const report=JSON.parse(fs.readFileSync(path.join(directory,'report-grands_moments.json'),'utf8'));
assert.deepEqual(report.failures,[]);assert.ok(report.checks>=12,'contrôles : '+report.checks);
const sorties=report.suivi.filter(e=>e.evenement==='sortie');
assert.ok(sorties.some(e=>e.moment==='mi-temps'&&e.marche)&&sorties.some(e=>e.moment==='fin'&&e.marche),'sorties de mi-temps et de fin jouées jusqu’à la marche : '+JSON.stringify(sorties));
console.log('Grands moments (Monde) : contrôles '+report.checks+' · sorties '+sorties.map(e=>e.moment+' '+Number(e.duree_reelle||0).toFixed(1)+' s').join(' · '));
fs.rmSync(directory,{recursive:true,force:true});
