'use strict';
const CDFranceCareer=(()=>{
 function startFrance(id){
  if(!Number.isInteger(id)||id<0||id>=30)throw Error('Club France invalide.');
  S={version:2,club:id,season:1,round:0,clubs:CDFranceClubs.clubs.map(c=>({id:c.id,name:c.name,abbr:c.abbr,color:c.color,base:c.base,cash:c.cashMillions*1e6,goal:c.goal,stadium:c.stadium,points:0,played:0,won:0,drawn:0,lost:0,pf:0,pa:0,bonus:0,form:[],players:Array.from({length:30},(_,j)=>makePlayer(c.id,j,c.base))})),schedule:[],lineup:[],reserves:[],tactic:'equilibre',training:'normal',physicalLoadVersion:1,collectivePrepVersion:1,collectiveFocus:'aucune',developmentFocusVersion:1,recruitmentIntelVersion:1,salaryDemandVersion:1,satisfactionVersion:1,relationsVersion:1,objectivesVersion:1,v39Version:1,integratedManagementVersion:1,worldVersion:1,morale:75,trust:70,history:[],news:['Bienvenue dans votre carrière France : trente clubs fictifs et deux divisions reliées.'],market:[],marketWeek:-1,phase:'league',playoff:null,live:null,lastReport:null,ledger:[],trained:false};
  CDFranceCompetition.beginSeason(S,true);setupOpposition();setupEconomy();setupDevelopment();club().players.forEach(ensureSatisfaction);v39Initialize();autoLineup();refreshMarket();setupManager();careerSetup();worldSetup();aiRosterYouthIntake();save();view='dashboard';entryScreen='game';
 }
 function context(pair){return CDFranceCompetition.currentFixtures(S).find(f=>f.pair[0]===pair[0]&&f.pair[1]===pair[1])||null;}
 function result(l){return {pair:l.pair.slice(),score:l.score.slice(),tries:l.tries.slice(),stats:JSON.parse(JSON.stringify(l.stats)),weather:l.weather,duration:l.minute,...(l.franceContext.phase!=='league'?{winner:l.winner,decision:JSON.parse(JSON.stringify(l.decision))}:{})};}
 function simulate(f){const l=createRugbyMatch(f.pair,null,true);for(let n=0;!l.finished;n++){if(n>500)throw Error('Limite de simulation France atteinte.');l.paused=false;advanceRugby(l);}applyMatchInjuries(l);return result(l);}
 function finishWeek(){
  if(S.franceMode.week>=34||S.live&&!S.live.finished)throw Error('Semaine indisponible.');
  trainWeek();captureReport();const fixtures=CDFranceCompetition.currentFixtures(S),ownFixture=CDFranceCompetition.userFixture(S),results=[];
  for(const f of fixtures){const r=S.live&&f.pair.includes(S.club)?result(S.live):simulate(f);updateOppositionMorale(r);CDFranceCompetition.record(S,r,f);worldRecordResult({...r,franceContext:f});results.push({...r,...f});}
  const own=results.find(r=>r.pair.includes(S.club));let won=false;if(own){const i=own.pair.indexOf(S.club),d=own.score[i]-own.score[1-i];won=own.winner!==undefined?own.winner===S.club:d>0;const before=S.morale;S.morale=clamp(S.morale+(won?6:d<0?-5:1),25,98);S.trust=clamp(S.trust+(won?3:d<0?-2:0),0,100);recordClubMorale(before,d);news(`${won?'Victoire':d<0?'Défaite':'Match nul'} : ${S.clubs[own.pair[0]].abbr} ${own.score.join(' – ')} ${S.clubs[own.pair[1]].abbr}.`);}
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
 return Object.freeze({start:startFrance,context,result,simulate,finishWeek,advance});
})();
