'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),preparation=require('../native/engine/epcr-preparation.cjs');
function fixture(t,mode='world',club=0){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-epcr-preparation-'));
 let b=createBridge({dataDir:dir,seed:827381,now:1794178800000}),serial=0;
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const send=(command,payload={})=>b.handle({id:++serial,command,payload});
 const good=(command,payload)=>{const r=send(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 settleClubMeetings(good('new_career',{mode,club}),(command,payload)=>good(command,payload));
 return {dir,send,good,disk:()=>fs.readFileSync(path.join(dir,'PrototypeGodot','donnees.json')),restart:()=>{b.close();b=createBridge({dataDir:dir,seed:1,now:10});}};
}
test('Monde et Champ : préparation EPCR consultative, pas une inscription officielle',t=>{
 for(const mode of ['world','world-champ']){
  const f=fixture(t,mode),m=f.good('snapshot'),p=m.epcrPreparation;
  assert.equal(p.season,'2026/27');assert.equal(p.competitionId,'champions');assert.equal(p.supported,true);
  assert.equal(p.candidates.length,m.squad.length);assert.deepEqual(p.registeredIds,m.squad.map(x=>x.id));
  assert.ok(p.candidates.every(x=>x.frontRow===null&&!x.qualificationKnown),'aucune qualification inventée à partir du poste');
  assert.match(p.notice,/sans inscription officielle/);assert.match(p.notice,/contractuelles/);
  assert.equal(p.registration.status,'invalid','effectif de Toulouse >42 : choisir une liste, pas tronquer silencieusement');
  assert.ok(p.registration.violations.some(x=>x.code==='registration-size'));
 }
});
test('Vrai worker : liste choisie, feuille et refus gardent disque, RNG, horloge et export exacts',t=>{
 const f=fixture(t),m=f.good('snapshot'),before=f.good('export').meta.exportText,bytes=f.disk();
 const ids=[...m.lineup,...m.reserves].reverse(),payload={registeredIds:ids,competitionId:m.epcrPreparation.competitionId};
 const p=f.good('epcr_preview',payload).epcrPreparation;
 assert.deepEqual(p.registeredIds,ids);assert.equal(p.registration.status,'unknown');assert.equal(p.teamSheet.status,'unknown');
 assert.equal(p.registration.counts.players,23);assert.equal(p.teamSheet.counts.players,23);
 assert.ok(p.registration.unknowns.some(x=>x.code==='registration-front-row'));
 const missing=ids.slice(1),next=f.good('epcr_preview',{...payload,registeredIds:missing}).epcrPreparation;
 assert.equal(next.teamSheet.status,'invalid');assert.ok(next.teamSheet.violations.some(x=>x.code==='sheet-unregistered-player'));
 const invalid=[{registeredIds:[...ids,ids[0]],competitionId:'champions'},
  {registeredIds:['not-owned'],competitionId:'champions'},
  {registeredIds:ids,competitionId:'challenge'},
  {registeredIds:ids,competitionId:'champions',confirmed:true},
  {registeredIds:Array(101).fill(ids[0]),competitionId:'champions'},
  {registeredIds:null,competitionId:'champions'}];
 for(const data of invalid){const r=f.send('epcr_preview',data);assert.equal(r.ok,false);assert.deepEqual(f.disk(),bytes);}
 assert.equal(f.good('export').meta.exportText,before);assert.deepEqual(f.disk(),bytes,'fichier contient aussi graine, horloge et store');
 assert.deepEqual(f.good('snapshot').epcrPreparation.registeredIds,m.epcrPreparation.registeredIds,'brouillon non stocké');
 const control=fixture(t);settleClubMeetings(f.good('train',{mode:'normal'}),(command,payload)=>f.good(command,payload));settleClubMeetings(control.good('train',{mode:'normal'}),(command,payload)=>control.good(command,payload));
 assert.deepEqual(JSON.parse(f.good('export').meta.exportText).state,JSON.parse(control.good('export').meta.exportText).state,'la prochaine commande aléatoire conserve la même trajectoire');
 assert.equal(JSON.parse(f.disk()).seed,JSON.parse(control.disk()).seed,'curseur RNG privé identique');
 assert.equal(JSON.parse(f.disk()).clock,JSON.parse(control.disk()).clock,'horloge privée identique');
});
test('La préparation conserve l’ancien document, son import et la reprise du vrai profil',t=>{
 const f=fixture(t,'world-champ'),before=f.good('export').meta.exportText,m=f.good('snapshot');
 const ids=m.squad.slice(0,30).map(x=>x.id);
 f.good('epcr_preview',{registeredIds:ids,competitionId:'champions'});
 f.restart();assert.equal(f.good('export').meta.exportText,before,'seed et horloge restaurées malgré options d’ouverture différentes');
 assert.deepEqual(f.good('snapshot').epcrPreparation.registeredIds,m.epcrPreparation.registeredIds);
 f.good('import',{text:before});assert.deepEqual(JSON.parse(f.good('export').meta.exportText).state,JSON.parse(before).state);
 assert.ok(!Object.hasOwn(JSON.parse(before).state.worldMode,'epcrPreparation'));
});
test('Fiction et clubs non européens n’exposent pas de faux dossier EPCR',t=>{
 const f=fixture(t,'fiction'),before=f.disk();
 assert.equal(f.good('snapshot').epcrPreparation,null);assert.equal(f.send('epcr_preview',{registeredIds:[],competitionId:'champions'}).ok,false);assert.deepEqual(f.disk(),before);
 const world=fixture(t,'world',14);assert.equal(world.good('snapshot').epcrPreparation,null);
});
test('La coupe Challenge et les saisons ultérieures restent explicitement distinctes',t=>{
 const f=fixture(t),base=f.good('snapshot');
 const model=JSON.parse(JSON.stringify(base));
 model.leagues=model.leagues.filter(c=>c.id!=='champions');
 model.leagues.find(c=>c.id==='challenge').pools=[{rows:[{id:model.club.id}]}];
 const challenge=preparation.project(model);
 assert.equal(challenge.competitionId,'challenge');assert.match(challenge.source,/ecc-rules/);
 model.meta.season=2;const future=preparation.project(model);
 assert.equal(future.season,'2027/28');assert.equal(future.supported,false);
 assert.ok(future.registration.violations.some(x=>x.code==='unsupported-season'));
 assert.match(future.notice,/aucune inscription/);
 const large=JSON.parse(JSON.stringify(base));large.squad=Array.from({length:101},(_,i)=>({...base.squad[0],id:'synthetic:'+i}));large.lineup=[];large.reserves=[];
 assert.equal(preparation.project(large).registration.counts.players,101,'une liste ancienne trop grande reste diagnostiquable sans casser le snapshot');
 assert.throws(()=>preparation.project(large,{competitionId:'champions',registeredIds:large.squad.map(p=>p.id)}),/100 au maximum/);
});
