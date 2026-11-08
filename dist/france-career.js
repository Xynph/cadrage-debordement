'use strict';
const CDFranceCareer=(()=>{
 // A common initializer supplies its roster before any contracts, development or world setup.
 // Its first AI intake is deferred: automatic cover would invent eight extra professionals.
 function startFrance(id,initial=null){
  if(!Number.isInteger(id)||id<0||id>=30)throw Error('Club France invalide.');
  S={version:2,...(initial?.rosterFoundation?{rosterFoundation:JSON.parse(JSON.stringify(initial.rosterFoundation))}:{}),...(initial?{commonDatabase:JSON.parse(JSON.stringify(initial.database))}:{}),club:id,season:1,round:0,clubs:CDFranceClubs.clubs.map(c=>({id:c.id,name:c.name,abbr:c.abbr,color:c.color,base:c.base,cash:c.cashMillions*1e6,goal:c.goal,stadium:c.stadium,points:0,played:0,won:0,drawn:0,lost:0,pf:0,pa:0,bonus:0,form:[],players:initial?initial.playersForClub(c.id):Array.from({length:30},(_,j)=>makePlayer(c.id,j,c.base))})),schedule:[],lineup:[],reserves:[],tactic:'equilibre',training:'normal',physicalLoadVersion:1,collectivePrepVersion:1,collectiveFocus:'aucune',developmentFocusVersion:1,recruitmentIntelVersion:1,salaryDemandVersion:1,satisfactionVersion:1,relationsVersion:1,objectivesVersion:1,v39Version:1,integratedManagementVersion:1,worldVersion:1,morale:75,trust:70,history:[],news:[initial?'Bienvenue dans votre carrière : base commune anonymisée, trente clubs et deux divisions reliées.':'Bienvenue dans votre carrière France : trente clubs fictifs et deux divisions reliées.'],market:[],marketWeek:-1,phase:'league',playoff:null,live:null,lastReport:null,ledger:[],trained:false};
  CDFranceCompetition.beginSeason(S,true);setupOpposition();setupEconomy();setupDevelopment();club().players.forEach(ensureSatisfaction);v39Initialize();autoLineup();refreshMarket();setupManager();careerSetup();worldSetup();if(!initial)aiRosterYouthIntake();save();view='dashboard';entryScreen='game';
 }
 function context(pair){return CDFranceCompetition.currentFixtures(S).find(f=>f.pair[0]===pair[0]&&f.pair[1]===pair[1])||null;}
 function ensureAISheet(c){
  if(c.id===S.club)return;
  let sh=buildSheet(c);
  while(true){
   // Une recrue peut entrer dans le XV et déplacer un autre joueur sur le banc.
   // Rechercher à nouveau le premier manque après chaque redistribution.
   const slot=[...sh.lineup,...sh.bench].findIndex(id=>!id);
   if(slot<0)break;
   if(c.players.length>=100)throw Error('Effectif IA '+c.abbr+' : plafond de 100 joueurs atteint, feuille qualifiée impossible.');
   if(professionalLoanReservations(c).length&&professionalPlaces(c)<=0)throw Error('Effectif IA '+c.abbr+' : places réservées aux retours de prêt, renfort indisponible.');
   const before=c.players.length;
   const target=slot<15?slot:[1,0,2,3,5,8,9,10][slot-15];
   if(!aiRosterPromote(c,target,true)){
    const ids=new Set([...S.clubs.flatMap(x=>x.players),...S.aiRoster.academies.flatMap(a=>a.players),...S.development.academy,...S.market,...S.economy.freeAgents].map(p=>p.id));let serial=500;
    while(ids.has('youth-'+c.id+'-'+S.season+'-'+serial))serial++;
    const p=academyPlayer(c.id,target,S.season,serial,true);
    p.rating=clamp(c.base-15+seedHash(p.id)%9,54,82);delete p.skills;ensureSkills(p);delete p.dev;ensureDevelopment(p);
    p.contractEnd=S.season+2;p.academy=false;c.players.push(p);aiRosterEvent(c.id,'emergency',p);
   }
   if(c.players.length<=before)throw Error('Effectif IA '+c.abbr+' : aucun renfort qualifié disponible pour compléter les 23.');
   sh=buildSheet(c);
  }
  if([...sh.lineup,...sh.bench].filter(Boolean).length!==23)throw Error('Effectif IA '+c.abbr+' : aucun renfort qualifié disponible pour compléter les 23.');
 }
 function result(l){return {pair:l.pair.slice(),score:l.score.slice(),tries:l.tries.slice(),stats:JSON.parse(JSON.stringify(l.stats)),weather:l.weather,duration:l.minute,...(l.franceContext.phase!=='league'?{winner:l.winner,decision:JSON.parse(JSON.stringify(l.decision))}:{})};}
 function simulate(f){const l=createRugbyMatch(f.pair,null,true);for(let n=0;!l.finished;n++){if(n>500)throw Error('Limite de simulation France atteinte.');l.paused=false;advanceRugby(l);}applyMatchInjuries(l);return result(l);}
 function recordOwnOutcome(r){
  if(!r)return false;const d=CDFranceCompetition.outcome(r,S.club),before=S.morale;
  S.morale=clamp(S.morale+(d>0?6:d<0?-5:1),25,98);S.trust=clamp(S.trust+(d>0?3:d<0?-2:0),0,100);recordClubMorale(before,d);
  news(`${d>0?'Victoire':d<0?'Défaite':'Match nul'} : ${S.clubs[r.pair[0]].abbr} ${r.score.join(' – ')} ${S.clubs[r.pair[1]].abbr}.`);return d>0;
 }
 function finishWeek(){
  if(S.franceMode.week>=34||S.live&&!S.live.finished)throw Error('Semaine indisponible.');
  trainWeek();captureReport();const fixtures=CDFranceCompetition.currentFixtures(S),ownFixture=CDFranceCompetition.userFixture(S),results=[];
  for(const f of fixtures){const r=S.live&&f.pair.includes(S.club)?result(S.live):simulate(f);updateOppositionMorale({...r,...f});CDFranceCompetition.record(S,r,f);worldRecordResult({...r,franceContext:f});results.push({...r,...f});}
  const own=results.find(r=>r.pair.includes(S.club)),won=recordOwnOutcome(own);
  financeWeek(ownFixture?.neutral?null:ownFixture?.pair,won);worldWeeklyEconomy(results);careerBoardWeekReview();recordSatisfactionRound(S.live);recordIndividualObjectivesRound(S.live);S.live=null;S.trained=false;CDFranceCompetition.closeWeek(S);
  if(S.phase==='ended'){for(const id of ['elite','accession'])careerRecord('trophy',id==='elite'?'Champion de l’élite':'Champion de la division accession',S.franceMode.leagues[id].champion,'france-'+id);S.worldManagement.champion=S.franceMode.leagues.elite.champion;news(S.ending);}
  refreshMarket();repairSheet();save();view='dashboard';
 }
 function advance(){
  if(S.franceMode.week!==34||S.live)throw Error('Terminez la saison avant l’intersaison.');
  worldEndSeason();careerSeasonEnd();closeIndividualObjectivesSeason();rollDevelopmentYear();settleContracts();S.season++;CDFranceCompetition.beginSeason(S);S.history=[];S.lastReport=null;S.ending=null;S.trained=false;
  for(const c of S.clubs){c.points=c.played=c.won=c.drawn=c.lost=c.pf=c.pa=c.bonus=0;c.form=[];c.morale=75;for(const p of c.players){p.condition=100;p.injury=0;p.managerLoad={minutes:0,streak:0};if(p.physicalLoad)p.physicalLoad.fatigue=0;}}
  ledgerEntry('Financement de début de saison',2500000);worldNewSeason();S.morale=75;beginDevelopmentSeason();resetSatisfactionSeason();v39SeasonReset();careerSeasonStart();autoLineup();if(sheetErrors().length)promoteCover();refreshMarket();managerMobilityOnSeasonStart();CDFranceCompetition.project(S);news(`Saison ${S.season} : les promotions et relégations ont été appliquées. Monde fermé sans Nationale.`);save();
 }
 return Object.freeze({start:startFrance,context,ensureAISheet,result,simulate,recordOwnOutcome,finishWeek,advance});
})();
