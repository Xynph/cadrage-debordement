'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const profile=process.env.CD_SUPPORT_SEASON_PROFILE==='1',costs=new Map();
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-season-'));let b=createBridge({dataDir:root,seed:411,now:1700000000000}),n=0;
const good=(command,payload={})=>{const started=performance.now();try{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;}finally{if(profile){const row=costs.get(command)||{command,count:0,ms:0};row.count++;row.ms+=performance.now()-started;costs.set(command,row);}}};
// Reprises réelles au début, au milieu et à la bascule de saison, puis dans
// plusieurs contextes tardifs. Les autres rencontres restent toutes jouées.
const restartWeeks=new Set([0,16,26,27,29,31,33]),checkpoints=[],weeks=[],matchWeeks=[],pureWeeks=[];
// Check the briefing in the actual atomic save. Public exports still cover
// every restart and each before/after purity comparison.
const savedCareer=()=>JSON.parse(JSON.parse(fs.readFileSync(path.join(root,'PrototypeGodot','donnees.json'),'utf8')).store['bdt-v1']);
const restart=(text,label)=>{good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,text,'Reprise exacte : '+label);checkpoints.push(label);};
const assertPure=week=>{const before=good('export').meta.exportText;good('snapshot');const after=good('export').meta.exportText;assert.equal(after,before,'Projection pure semaine '+week);pureWeeks.push(week);return after;};
try{
 let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),(command,payload)=>good(command,payload)),briefed=0,delegated=0;
 while(m.meta.week<34){
  const week=m.meta.week;weeks.push(week);
  const support=m.clubLife.clubSupport;assert.equal(support.context.week,m.meta.week);assert.equal(support.context.club,29);
  const pureText=week>=27?assertPure(week):null;
  if(m.next){
   matchWeeks.push(week);
   m=settleClubMeetings(good('train'),(command,payload)=>good(command,payload));m=good('auto_lineup');
   assert.equal(support.briefing.available,true,'Briefing disponible pour chaque rencontre.');
   m=good('strategic_briefing',{context:support.context,fixture:support.briefing.fixture,plan:'espaces'});briefed++;
   m=good('begin_match');const state=savedCareer();assert.equal(state.live.v69Briefing.plan,'espaces');assert.equal(state.live.v69Briefing.opponent,m.next.pair.find(id=>id!==29));
   if(restartWeeks.has(week))restart(good('export').meta.exportText,'S1w'+week+' live');
   good('delegate');delegated++;
  }else if(restartWeeks.has(week))restart(pureText??good('export').meta.exportText,'S1w'+week+' sans match');
  m=settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));
 }
 assert.deepEqual(weeks,Array.from({length:34},(_,i)=>i),'Les 34 semaines sont réellement avancées.');
 assert.ok(matchWeeks.length>=30,'Toutes les rencontres de la saison régulière sont jouées.');assert.deepEqual(matchWeeks.filter(w=>w<30),Array.from({length:30},(_,i)=>i));assert.equal(briefed,matchWeeks.length);assert.equal(delegated,matchWeeks.length);
 assert.equal(m.clubLife.clubSupport.context.week,34);const seasonEndText=assertPure(34);assert.deepEqual(pureWeeks,[27,28,29,30,31,32,33,34]);restart(seasonEndText,'S1w34 fin de saison');
 m=settleClubMeetings(good('next_season',{confirmed:true}),(command,payload)=>good(command,payload));assert.equal(m.clubLife.clubSupport.context.season,2);assert.equal(m.clubLife.clubSupport.context.week,0);assert.equal(m.clubLife.clubSupport.briefing.selected,'neutre');
 const secondContext=m.clubLife.clubSupport.context;
 m=good('staff_meeting',{context:secondContext,plan:'cohesion'});
 const offer=m.clubLife.clubSupport.agents.players.flatMap(p=>p.quotes).find(q=>q.affordable&&q.policy==='equilibre');assert.ok(offer,'Une prolongation doit rester négociable en deuxième saison.');
 m=good('agent_negotiate',{context:secondContext,id:offer.id,years:offer.years,policy:offer.policy});
 const secondText=good('export').meta.exportText;good('import',{text:secondText});restart(secondText,'S2w0 réunion et agent importés');
 // La semaine 31 dépend du classement (phase finale ou non), que le JIFF peut modifier.
 assert.deepEqual(checkpoints.map(c=>c.startsWith('S1w31 ')?'S1w31':c),['S1w0 live','S1w16 live','S1w26 live','S1w27 live','S1w29 live','S1w31','S1w33 sans match','S1w34 fin de saison','S2w0 réunion et agent importés']);
 console.log('Support saison réelle club29 : '+weeks.length+' semaines, '+briefed+' briefings figés/vérifiés et '+delegated+' matchs délégués, '+pureWeeks.length+' projections pures (27–34), '+checkpoints.length+' reprises exactes dont finS1 et import S2, reset contexte saison2 PASS. '+root);
}finally{b.close();if(profile)console.log('SUPPORT_SEASON_PROFILE '+JSON.stringify({requests:n,commands:[...costs.values()].sort((a,b)=>b.ms-a.ms).map(r=>({...r,ms:Math.round(r.ms)}))}));}
