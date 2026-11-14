'use strict';
// Liaisons entre temps forts contigus dans le vrai jeu, carrière Monde (seul mode de carrière depuis
// le 13/11/2026) : la régie relie en 3D les temps forts contigus, à vitesse réelle même quand les
// temps forts sont accélérés pour le test, et garde l'écran 2D entre deux temps forts non contigus.
// Graine 3 (CD_LIAISON_GRAINE) : en-avant puis touche enchaînés à la 17e minute (liaison par coupe).
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-liaison-monde : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-liaison-monde-'));
{
 const dataDir=fs.mkdtempSync(path.join(directory,'carriere-'));
 const bridge=createBridge({dataDir,seed:7,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true});
 let id=0;const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 let model=call('new_career',{mode:'world-champ',club:0});
 for(let day=0;day<40;day++){model=settleClubMeetings(model,call);if(model.meta.calendarCadence?.matchReady)break;model=call('advance_day',{fromDate:model.meta.calendarToday});}
 model=settleClubMeetings(model,call);model=call('auto_lineup');if(!model.selection?.valid)call('promote_cover',{confirmed:true});
 assert.ok(call('begin_match').live,'match Monde commencé');
 fs.writeFileSync(path.join(directory,'monde.json'),call('export').meta.exportText);
 bridge.close?.();fs.rmSync(dataDir,{recursive:true,force:true});
}
// Préparation seule pour rejouer exactement cette carrière avec la sonde graphique.
if(process.env.CD_LIAISON_EXPORT){
 const target=process.env.CD_LIAISON_EXPORT;
 assert.ok(path.isAbsolute(target),'CD_LIAISON_EXPORT : chemin absolu requis');
 fs.copyFileSync(path.join(directory,'monde.json'),target,fs.constants.COPYFILE_EXCL);
 fs.rmSync(directory,{recursive:true,force:true});
 console.log('Export jetable world-champ, graine 7, club 0 : '+target);process.exit(0);
}
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'liaison','PrototypeGodot'),CD_MATCH_TEMPS_FORTS_ARTIFACTS:directory,
 CD_MATCH_TEMPS_FORTS_MODE:'liaison',CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4',CD_GODOT_SEED:process.env.CD_LIAISON_GRAINE||'3',CD_LIAISON_MINUTES:process.env.CD_LIAISON_MINUTES||'18',CD_LIAISON_ATTENDUES:process.env.CD_LIAISON_ATTENDUES||'1'};
for(const name of ['CD_MODES_HERITES','CD_MATCH_TEMPS_FORTS_NIVEAU','CD_MATCH_GESTES','CD_MATCH_CHOREGRAPHE','CD_MATCH_TEMPS_FORTS_ENTRACTE'])delete env[name];
const result=spawnSync(godot,['--headless','--max-fps','60','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-temps-forts.gd')],{env,encoding:'utf8',windowsHide:true,timeout:1200000});
const output=(result.stdout||'')+(result.stderr||'');console.log(output);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
const report=JSON.parse(fs.readFileSync(path.join(directory,'report-liaison.json'),'utf8'));
assert.deepEqual(report.failures,[]);assert.ok(report.checks>=8,'contrôles : '+report.checks);
const liaisons=report.suivi.filter(e=>e.evenement==='liaison');
assert.ok(liaisons.length>=1,'liaisons : '+JSON.stringify(report.suivi.map(e=>e.evenement)));
console.log('Liaisons (Monde) : '+liaisons.map(e=>e.type+(e.coupe?' (coupe)':'')+' '+Number(e.duree_reelle||0).toFixed(1)+' s').join(' · ')+' · contrôles '+report.checks);
fs.rmSync(directory,{recursive:true,force:true});
