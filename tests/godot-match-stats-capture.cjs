'use strict';
// Captures de l'écran entre les temps forts avec la feuille de statistiques : un entracte en cours de
// match et l'écran « Match terminé », dans la vraie interface avec le vrai moteur. Outil manuel : sans
// CD_STATS_PNG_ENTRACTE et CD_STATS_PNG_FIN, il ne fait rien (la CI le saute). Sous Linux sans écran,
// lancer dans xvfb-run.
//
//   CD_GODOT_EXE (ou CD_GODOT_EXECUTABLE)  exécutable Godot 4.7.2
//   CD_STATS_PNG_ENTRACTE  PNG absolu de l'entracte
//   CD_STATS_PNG_FIN       PNG absolu de l'écran de fin de match
//   CD_STATS_ENTRACTE      numéro de l'entracte capturé (défaut 3)
//   CD_STATS_SEED          graine du moteur (défaut 7)
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const entracte=process.env.CD_STATS_PNG_ENTRACTE,fin=process.env.CD_STATS_PNG_FIN;
if(!entracte||!fin){console.log('SKIP godot-match-stats-capture : outil manuel (CD_STATS_PNG_ENTRACTE et CD_STATS_PNG_FIN absents).');process.exit(0);}
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.error('CD_GODOT_EXE doit désigner l’exécutable Godot.');process.exit(2);}
if(!path.isAbsolute(entracte)||!path.isAbsolute(fin)){console.error('Les chemins des captures doivent être absolus.');process.exit(2);}
const seed=/^\d+$/.test(process.env.CD_STATS_SEED||'')?process.env.CD_STATS_SEED:'7';
const work=fs.mkdtempSync(path.join(os.tmpdir(),'cd-stats-capture-'));
// Carrière Monde (le seul mode), avancée jusqu'au jour du premier match, arrêtée à la causerie d'avant-match.
// Dans un processus à part : le moteur de la carrière libère sa mémoire avant le lancement de Godot.
const save=path.join(work,'live.json');
const generation=`
const fs=require('node:fs'),path=require('node:path');
const {createBridge}=require(${JSON.stringify(path.resolve(__dirname,'../native/engine/worker.cjs'))}),{settleClubMeetings}=require(${JSON.stringify(path.resolve(__dirname,'helpers/club-meetings.cjs'))});
const dataDir=fs.mkdtempSync(path.join(${JSON.stringify(work)},'carriere-'));
const bridge=createBridge({dataDir,seed:7,now:1700000000000,dailyCalendar:true,mandatoryPress:false,internationalCareer:true});
let id=0;const send=(command,payload={})=>bridge.handle({id:++id,command,payload});
const settle=model=>settleClubMeetings(model,(c,p)=>{const r=send(c,p);if(!r.ok)throw Error(c+' : '+r.error);return r.model;});
let model=settle(send('new_career',{mode:'world-champ',club:0}).model),live=false;
for(let jour=0;jour<120&&!live;jour++){
 const r=send('begin_match');
 if(r.ok&&r.model.live){live=true;break;}
 const a=send('advance_day',{fromDate:(r.model||model).calendarPlanning?.today});
 if(!a.ok)throw Error('advance_day : '+a.error);
 model=settle(a.model);
}
if(!live)throw Error('Aucun match joué en 120 jours.');
fs.writeFileSync(${JSON.stringify(save)},send('export').model.meta.exportText);
process.exit(0);`;
const prepare=spawnSync(process.execPath,['--max-old-space-size=3000','-e',generation],{encoding:'utf8',maxBuffer:64*1024*1024});
if(prepare.status!==0||!fs.existsSync(save)){console.error('Carrière : statut '+prepare.status+' signal '+prepare.signal+' '+(prepare.stdout||'')+(prepare.stderr||''));process.exit(2);}
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(work,'PrototypeGodot'),CD_GODOT_SEED:seed,CD_STATS_SAVE:save,
 CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4'};
for(const nom of ['CD_MATCH_TEMPS_FORTS','CD_MATCH_TEMPS_FORTS_NIVEAU'])delete env[nom];
const result=spawnSync(godot,['--rendering-method','gl_compatibility','--windowed','--resolution','1280x720','--fixed-fps','30','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-stats-capture.gd')],{env,encoding:'utf8',timeout:3000000,maxBuffer:64*1024*1024});
const output=(result.stdout||'')+(result.stderr||'');
fs.rmSync(work,{recursive:true,force:true});
console.log(output.split('\n').filter(l=>/FIN|CAPTURE|ERROR|SCRIPT/.test(l)).join('\n'));if(result.status)console.log(output.slice(-3000));
if(result.error)throw result.error;
process.exit(result.status||0);
