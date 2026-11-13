'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs'),editor=require('../native/engine/competition-editor.cjs');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'oval-deepen-six-')),now=1700000000000;let bridge,id=0;
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
function raw(command,payload={}){return bridge.handle({id:++id,command,payload});}
function good(command,payload={}){const r=raw(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
const state=()=>JSON.parse(good('export').meta.exportText).state;
try{
 bridge=createBridge({dataDir:directory,seed:827381,now});
 const document=editor.generate({name:'Ligue de réception',clubs:Array.from({length:14},(_,i)=>'Club personnalisé '+i),doubleRound:true});
 let m=settleClubMeetings(good('new_career',{mode:'custom',document,club:0,confirmed:true}),(command,payload)=>good(command,payload));
 assert.equal(m.club.presentation.name,document.clubs[0].name);assert.equal(m.leagues[0].name,document.name);
 if(!m.clubLife.staffCareer.active)m=good('staff_career_enable',{confirmed:true,context:m.clubLife.staffCareer.context});
 m=good('staff_employment_enable',{confirmed:true,context:m.clubLife.staffEmployment.context});
 const coach=m.clubLife.staffEmployment.own.find(p=>p.role==='coach');assert.ok(coach);
 m=good('staff_employment_adopt',{confirmed:true,context:m.clubLife.staffEmployment.context,staffId:coach.id,salary:coach.salary});
 m=good('player_match_history_enable',{confirmed:true,context:m.clubLife.playerMatchHistory.context});
 m=good('youth_development_enable',{confirmed:true,context:m.clubLife.youthDevelopment.context});
 m=good('staff_mentoring_enable',{confirmed:true,context:m.clubLife.staffMentoring.context});
 const mentor=m.clubLife.staffMentoring.mentors[0],pupil=m.clubLife.staffMentoring.players[0];assert.ok(mentor&&pupil);
 m=good('staff_mentor_assign',{confirmed:true,context:m.clubLife.staffMentoring.context,staffId:mentor.id,playerId:pupil.id,focus:pupil.focusOptions[0].key});
 m=good('youth_development_plan',{confirmed:true,context:m.clubLife.youthDevelopment.context,playerId:pupil.id,plan:'general',focus:null});
 assert.equal(m.clubLife.staffMentoring.assignments[0].active,false,'explicit youth plan remains authoritative');
 const candidate=m.clubLife.interclubMarket.candidates.find(p=>p.available&&p.salary*2<=100000);assert.ok(candidate);
 const offer={playerId:candidate.id,sellerId:candidate.clubId,fee:candidate.fee*2,salary:candidate.salary*2,sourceSalary:candidate.sourceSalary,contractEnd:candidate.contractEnd,context:m.clubLife.interclubMarket.context};
 const profile=path.join(m.meta.dataDir,'donnees.json'),before=good('export').meta.exportText,bytes=fs.readFileSync(profile);
 const negotiation=good('interclub_negotiate',offer).meta.interclubNegotiation;
 assert.equal(hash(good('export').meta.exportText),hash(before),'negotiation is read-only with all domains active');assert.equal(hash(fs.readFileSync(profile)),hash(bytes));
 const winner=negotiation.winner;assert.ok(winner);const initial=state(),initialCash=initial.clubs.reduce((n,c)=>n+c.cash,0);
 m=good('interclub_auction',{...offer,confirmed:true,expectedWinner:winner.clubId,expectedFee:winner.fee,expectedSalary:winner.salary});
 assert.equal(state().clubs.reduce((n,c)=>n+c.cash,0),initialCash,'auction conserves money across actual clubs');
 assert.equal(state().clubs.flatMap(c=>c.players).filter(p=>p.id===candidate.id).length,1);
 settleClubMeetings(good('train',{mode:'normal'}),(command,payload)=>good(command,payload));good('auto_lineup');m=good('snapshot');
 if(!m.selection.valid){good('promote_cover',{confirmed:true});m=good('auto_lineup');}
 assert.ok(m.selection.valid);good('begin_match');good('delegate');m=settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));
 const after=state();assert.equal(after.playerMatchHistory.matches.length,1,'one finished match captured once');
 assert.equal(after.staffEmployment.payments.length,1,'one paid staff week');assert.equal(after.staffEmployment.payments[0].amount,coach.salary);
 const row=after.youthDevelopment.rows.find(p=>p.id===pupil.id);assert.ok(row&&row.observations.length);
 assert.equal(m.club.presentation.name,document.clubs[0].name);
 const exported=good('export').meta.exportText,committed=fs.readFileSync(profile);
 good('snapshot');assert.equal(hash(fs.readFileSync(profile)),hash(committed),'projections do not rewrite profile');
 bridge.close();bridge=createBridge({dataDir:directory,now});
 assert.equal(hash(good('export').meta.exportText),hash(exported),'all optional domains resume together');
 good('import',{text:exported});assert.equal(hash(good('export').meta.exportText),hash(exported),'strict import preserves the combined career and RNG');
 const rejected=raw('new_career',{mode:'custom',document:{...document,clubs:document.clubs.slice(0,2)},club:0,confirmed:true});assert.equal(rejected.ok,false);
 assert.equal(hash(good('export').meta.exportText),hash(exported),'refused replacement keeps all six systems');
 console.log('Approfondissements : custom + salaires + mentorat + jeunes + enchère + match individuel + reprise/import PASS.');
}finally{bridge?.close();fs.rmSync(directory,{recursive:true,force:true});}
