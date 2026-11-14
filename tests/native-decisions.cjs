'use strict';
// Décisions natives en carrière Monde (world-champ, seul mode de jeu) : dossiers purs, recrutement et
// prolongations négociés, séances, formation, délégations, missions, bilan et reprise exacte.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {skipMatchTalk}=require('./helpers/scene-match-talks.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-decisions-'));let seq=0,b;
// Même réglage que le vrai jeu : calendrier journalier, presse obligatoire, carrière internationale.
const open=()=>createBridge({dataDir:path.join(root,'monde'),seed:213,now:1794315600000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true});
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const bad=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,false,command+' doit être refusé');};
const settle=model=>settleClubMeetings(model,(command,payload)=>good(command,payload));
// Avance jour par jour jusqu'au jour du prochain match du club.
const toMatchDay=model=>{
 for(let day=0;day<150;day++){
  model=settle(model);
  if(model.meta.calendarCadence?.matchReady&&model.next)return model;
  model=good('advance_day',{fromDate:model.meta.calendarToday});
 }
 assert.fail('aucun jour de match en 150 journées');
};
try{
 b=open();
 let m=settle(good('new_career',{mode:'world-champ',club:102}));
 assert.ok(m.decisions,'Le dossier de décisions doit être accessible dans Godot.');
 const capacity=m.decisions.recruitment.capacity;
 assert.ok(capacity>=42&&capacity<=100,'Capacité professionnelle bornée à 42-100 (effectif de référence + 6).');
 assert.ok(m.squad.length<capacity,'Places libres en début de carrière.');assert.ok(m.market.some(p=>p.available),'Le marché doit permettre de recruter.');
 assert.equal(m.decisions.recruitment.needs.length,15);assert.equal(m.decisions.preparation,null,'Pas de dossier adverse en avant-saison, avant la première rencontre.');
 assert.equal(m.decisions.development.academy.length,60);
 const before=good('export').meta.exportText,file=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file);
 for(let i=0;i<5;i++)good('snapshot');assert.equal(good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(file),bytes,'La lecture de tous les dossiers ne modifie ni disque ni RNG.');
 const recruit=m.market.find(p=>p.available);const cash=m.finance.cash,squadSize=m.squad.length;
 const recruitTerms={playerId:recruit.id,years:1,confirmed:true};
 m=good('recruit',{...recruitTerms,salary:1000});assert.equal(m.meta.negotiation.status,'counter');
 const recruitCounter=m.meta.negotiation;
 m=good('snapshot');assert.equal(m.meta.negotiation,undefined);
 assert.deepEqual(m.market.find(p=>p.id===recruit.id).negotiation,{status:'counter',salary:recruitCounter.salary,years:1,attempts:1});
 assert.equal(m.finance.cash,cash);
 good('shutdown');b=open();m=good('snapshot');
 assert.deepEqual(m.market.find(p=>p.id===recruit.id).negotiation,{status:'counter',salary:recruitCounter.salary,years:1,attempts:1});
 m=good('recruit',{playerId:recruit.id,salary:100000,years:1,confirmed:true});assert.equal(m.meta.negotiation.status,'signed');assert.equal(m.squad.length,squadSize+1);assert.equal(m.finance.cash,cash-recruit.fee);
 m=settle(m);
 const renewal=m.squad.find(p=>p.renewal.available&&p.salary>2000);
 assert.ok(renewal,'Le club offre un contrat renouvelable avec un salaire supérieur au plancher.');
 const renewalTerms={playerId:renewal.id,years:renewal.renewal.minYears,confirmed:true};
 const renewalCash=m.finance.cash,renewalWage=m.finance.wage;
 for(let i=1;i<=3;i++){
  m=good('extend_contract',{...renewalTerms,salary:1000});
  const response=m.meta.negotiation;
  assert.equal(response.status,i<3?'counter':'withdrawn');
  const quote=good('snapshot').squad.find(p=>p.id===renewal.id).renewal;
  if(i<3)assert.deepEqual(quote.negotiation,{status:'counter',salary:response.salary,years:renewalTerms.years,attempts:i});
  else{assert.deepEqual(quote.negotiation,{status:'withdrawn'});assert.match(quote.reason,/prochaine journée/);}
  assert.equal(quote.available,i<3);
  assert.equal(m.finance.cash,renewalCash);assert.equal(m.finance.wage,renewalWage);
 }
 const locked=fs.readFileSync(file);
 bad('extend_contract',{...renewalTerms,salary:100000});
 assert.deepEqual(fs.readFileSync(file),locked,'Un quatrième essai refusé conserve le profil.');
 m=good('set_delegation',{key:'lineup',enabled:true});assert.equal(m.decisions.delegation.lineup,true);good('set_delegation',{key:'lineup',enabled:false});bad('set_delegation',{key:'contracts',enabled:true});bad('set_delegation',{key:'training',enabled:'yes'});
 m=good('set_collective_focus',{focus:'conquete'});assert.equal(m.decisions.training.collective.selected,'conquete');bad('set_collective_focus',{focus:'magic'});
 m=good('set_opponent_level',{level:'expert'});assert.equal(m.decisions.difficulty.selected,'expert');bad('set_opponent_level',{level:'cheat'});
 const prospect=m.decisions.development.academy[0];bad('promote_academy',{playerId:prospect.id});
 m=good('set_development_focus',{playerId:prospect.id,focus:prospect.development.options[1].id});assert.equal(m.decisions.development.academy.find(p=>p.id===prospect.id).development.focus,prospect.development.options[1].id);
 const wage=m.finance.wage;m=good('promote_academy',{playerId:prospect.id,confirmed:true});assert.ok(m.squad.some(p=>p.id===prospect.id));assert.equal(m.finance.wage,wage+prospect.salary);assert.ok(!m.decisions.development.academy.some(p=>p.id===prospect.id));
 const c=m.finance.cash;m=good('scout_mission',{family:0,maxAge:30,budget:1000000,maxWage:20000,confirmed:true});assert.equal(m.finance.cash,c-5000);assert.equal(m.decisions.recruitment.missions[0].remaining,2);bad('scout_mission',{family:9,maxAge:30,budget:1000000,maxWage:20000,confirmed:true});
 // Le jour du match : dossier adverse, séance verrouillant les choix, direct puis bilan.
 m=toMatchDay(m);
 assert.ok(m.decisions.preparation.opponent.id!==m.club.id);assert.equal(m.decisions.preparation.domains.length,6);
 settle(good('train',{mode:'normal'}));bad('set_collective_focus',{focus:'defence'});bad('set_development_focus',{playerId:m.decisions.development.academy[0].id,focus:'equilibre'});
 m=good('auto_lineup');if(!m.selection.valid)good('promote_cover',{confirmed:true});
 m=skipMatchTalk(good('begin_match'),good);assert.ok(m.live);bad('set_delegation',{key:'training',enabled:true});bad('set_opponent_level',{level:'decouverte'});
 m=good('pause',{paused:true});assert.equal(m.decisions.liveAdvice.canAct,true);
 const liveBefore=good('export').meta.exportText;for(let i=0;i<3;i++)good('snapshot');assert.equal(good('export').meta.exportText,liveBefore);
 m=skipMatchTalk(good('delegate'),good);assert.ok(m.decisions.report.notes.length);assert.ok(m.decisions.report.plans);
 if(m.live)m=skipMatchTalk(good('finish_round'),good);
 m=settle(m);m=good('snapshot');assert.ok(m.decisions.report.notes.length,'Bilan consultable après validation.');
 const saved=good('export').meta.exportText;good('shutdown');b=open();assert.equal(good('export').meta.exportText,saved,'Reprise exacte des décisions persistées.');
 console.log('Décisions natives Monde : dossiers purs, recrutement, négociations, séances, formation, délégations, missions et bilan/reprise PASS.');
}finally{b?.close();fs.rmSync(root,{recursive:true,force:true});}
