'use strict';
// Championnats actifs « comme FM » : choix détaillé / résultats rapides par championnat du Monde.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),vm=require('node:vm');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const leagueDetail=require('../native/engine/league-detail.cjs');

// Le contexte VM du worker est capturé pour interroger directement le moteur.
let captured=null;
const createContext=vm.createContext;
vm.createContext=function(...args){const c=createContext.apply(this,args);if(!captured)captured=c;return c;};
const {createBridge}=require('../native/engine/worker.cjs');

const WORLD=['elite','accession','prem','urc','srp','jlo-d1','jlo-d2','nationale','champ'];

test('Estimation : plus de championnats détaillés, jamais plus rapide',()=>{
 const machines=[{},{serialMs:leagueDetail.REFERENCE.benchmarkMs.serial*2,computeMs:leagueDetail.REFERENCE.benchmarkMs.compute*2,cores:2,memoryGb:4},{cores:16,memoryGb:32}];
 const order=leagueDetail.LEVELS.map(l=>l.id);
 for(const machine of machines){
  let prior=null;
  for(let n=0;n<=WORLD.length;n++){
   const e=leagueDetail.estimate({detailed:WORLD.slice(0,n),machine});
   assert.ok(e.weekMs>0&&e.seasonMs>=e.weekMs);
   if(prior){assert.ok(e.seasonMs>prior.seasonMs,'championnat ajouté : '+WORLD[n-1]);assert.ok(order.indexOf(e.level)>=order.indexOf(prior.level));}
   prior=e;
  }
 }
 const slow=leagueDetail.estimate({detailed:WORLD,machine:machines[1]}),fast=leagueDetail.estimate({detailed:WORLD,machine:machines[2]});
 assert.ok(slow.seasonMs>fast.seasonMs,'une machine deux fois plus lente est estimée plus lente');
 assert.throws(()=>leagueDetail.estimate({detailed:'elite'}),/Championnats actifs/);
 const table=leagueDetail.costTable({});
 assert.equal(table.levels.length,5);
 for(const id of WORLD)assert.ok(table.leagues[id].extraDetailedMs>0&&table.leagues[id].quickMs>=0,id);
 const sum=table.baseSeasonMs+WORLD.reduce((n,id)=>n+table.leagues[id].extraDetailedMs,0);
 assert.ok(Math.abs(sum-leagueDetail.estimate({detailed:WORLD}).seasonMs)<=WORLD.length,'la jauge de l’interface additionne le même tableau');
});

test('Banc d’essai : mesure positive et stable',()=>{
 const b=leagueDetail.benchmark();
 assert.equal(b.version,1);assert.ok(b.serialMs>0&&b.computeMs>0);
});

test('Carrière Monde : choix enregistré, validé, résultats rapides cohérents sur une saison',()=>{
 const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-league-detail-'));
 let serial=0,bridge;
 const raw=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const go=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 try{
  bridge=createBridge({dataDir:root,seed:827381,now:1794178800000});vm.createContext=createContext;
  assert.ok(captured,'contexte du moteur capturé');
  const run=code=>vm.runInContext(code,captured);
  // Banc d'essai sans carrière.
  const bench=go('league_benchmark',{cores:8,memoryGb:16}).meta.leagueBenchmark;
  assert.ok(bench.serialMs>0&&bench.costs.leagues.urc.extraDetailedMs>0&&bench.cores===8);
  assert.equal(raw('league_benchmark',{gpu:1}).ok,false);
  // Choix invalides refusés avant toute création.
  for(const bad of ['urc',['inconnu'],['urc','urc'],[1]])assert.equal(raw('new_career',{mode:'world-champ',club:0,detailedLeagues:bad}).ok,false,JSON.stringify(bad));
  let model=settleClubMeetings(go('new_career',{mode:'world-champ',club:0,detailedLeagues:['urc']}),go);
  const own=model.clubLife.leagueDetail.own;
  assert.equal(own,'elite');
  let state=JSON.parse(go('export').meta.exportText).state;
  assert.deepEqual(state.leagueDetail,{version:1,policy:'league-detail-v1',detailed:['elite','urc'],pending:null},'le championnat du club est toujours détaillé');
  assert.deepEqual(model.clubLife.leagueDetail.leagues.filter(l=>l.detailed).map(l=>l.id),['elite','urc']);

  // Une saison complète de Premiership (résultats rapides) jouée par le moteur léger.
  const season=JSON.parse(run(`(()=>{
   const fixtures=S.worldMode.fixtures.filter(f=>f.competitionId==='prem'&&f.phase==='league');
   const before=Object.fromEntries(S.worldMode.leagues.prem.members.flatMap(id=>S.clubs[id].players).map(p=>[p.id,p.dev?.minutes||0]));
   const quick=fixtures.every(f=>CDLeagueDetail.quickFixture(S,f));
   // Semaine après semaine : l'entraînement hebdomadaire soigne et récupère comme en carrière.
   let week=null;
   const results=fixtures.slice().sort((a,b)=>a.week-b.week).map(f=>{if(f.week!==week){week=f.week;S.trained=false;trainWeek();S.trained=false;}const r=CDLeagueDetail.simulate(S,f);CDWorldValidation.result({...r,fixtureId:f.id,competitionId:f.competitionId,season:S.season,phase:f.phase},f,null,5);return r;});
   const players=S.worldMode.leagues.prem.members.flatMap(id=>S.clubs[id].players);
   const table=Object.fromEntries(S.worldMode.leagues.prem.members.map(id=>[id,0]));
   for(const r of results){const d=r.score[0]-r.score[1];table[r.pair[0]]+=d>0?4:d===0?2:0;table[r.pair[1]]+=d<0?4:d===0?2:0;}
   const power=id=>{const c=S.clubs[id];return c.players.map(p=>p.rating).sort((a,b)=>b-a).slice(0,15).reduce((a,b)=>a+b,0)/15;};
   const own=S.worldMode.fixtures.filter(f=>f.phase==='league'&&(f.homeId===S.club||f.awayId===S.club));
   return JSON.stringify({quick,matches:results.length,
    points:results.reduce((n,r)=>n+r.score[0]+r.score[1],0)/results.length,
    tries:results.reduce((n,r)=>n+r.tries[0]+r.tries[1],0)/results.length,
    homeWins:results.filter(r=>r.score[0]>r.score[1]).length/results.length,
    table:Object.entries(table).map(([id,pts])=>[power(Number(id)),pts]),
    injured:players.filter(p=>p.injury>0).length/players.length,
    played:players.filter(p=>(p.dev?.minutes||0)>before[p.id]).length/players.length,
    detailedFixtures:{elite:S.worldMode.fixtures.filter(f=>f.competitionId==='elite').some(f=>CDLeagueDetail.quickFixture(S,f)),
     urc:S.worldMode.fixtures.filter(f=>f.competitionId==='urc').some(f=>CDLeagueDetail.quickFixture(S,f)),
     own:own.some(f=>CDLeagueDetail.quickFixture(S,f)),
     knockout:S.worldMode.fixtures.filter(f=>!['league','pool'].includes(f.phase)).some(f=>CDLeagueDetail.quickFixture(S,f))}});
  })()`));
  console.log(JSON.stringify({points:season.points,tries:season.tries,homeWins:season.homeWins,injured:season.injured,played:season.played}));
  assert.equal(season.quick,true);assert.equal(season.matches,90);
  assert.ok(season.points>=35&&season.points<=65,'points par match : '+season.points);
  assert.ok(season.tries>=4&&season.tries<=8,'essais par match : '+season.tries);
  assert.ok(season.homeWins>=.45&&season.homeWins<=.85,'victoires à domicile : '+season.homeWins);
  assert.ok(season.injured<.2,'blessés en fin de saison : '+season.injured);
  assert.ok(season.played>.3,'progression : des joueurs gagnent du temps de jeu');
  // Les équipes les plus fortes finissent en moyenne devant (corrélation positive).
  const xs=season.table.map(r=>r[0]),ys=season.table.map(r=>r[1]),mx=xs.reduce((a,b)=>a+b)/xs.length,my=ys.reduce((a,b)=>a+b)/ys.length;
  const cov=xs.reduce((n,x,i)=>n+(x-mx)*(ys[i]-my),0);assert.ok(cov>0,'la hiérarchie sportive est respectée');
  assert.deepEqual(season.detailedFixtures,{elite:false,urc:false,own:false,knockout:false});

  // Deux semaines réelles : les résultats rapides passent la validation de sauvegarde et l'import.
  for(let week=0;week<2;week++){
   if(model.next){if(!model.selection.valid){go('auto_lineup');if(!go('snapshot').selection.valid)go('promote_cover',{confirmed:true});}go('begin_match');go('delegate');}
   model=settleClubMeetings(go('finish_round'),go);
  }
  const text=go('export').meta.exportText;state=JSON.parse(text).state;
  assert.ok(state.history.some(r=>r.competitionId==='nationale'),'la Nationale a joué en résultats rapides');
  go('import',{text});

  // Changement en cours de partie : prévu pour la saison suivante, puis appliqué.
  model=go('league_detail_set',{detailed:['prem','jlo-d1']});
  assert.deepEqual(model.clubLife.leagueDetail.pending,['elite','prem','jlo-d1']);
  assert.deepEqual(model.clubLife.leagueDetail.leagues.filter(l=>l.detailed).map(l=>l.id),['elite','urc'],'aucun effet avant la nouvelle saison');
  assert.equal(raw('league_detail_set',{detailed:['nulle-part']}).ok,false);
  assert.equal(raw('league_detail_set',{detailed:[],extra:1}).ok,false);
  run(`(()=>{S.leagueDetail.pending=['elite','prem','jlo-d1'];CDLeagueDetail.applyPending(S);})()`);
  assert.deepEqual(JSON.parse(run('JSON.stringify(S.leagueDetail)')).detailed,['elite','prem','jlo-d1']);
  // Sauvegardes trafiquées refusées.
  const forged=JSON.parse(text);
  for(const breakage of [s=>{s.leagueDetail.detailed=['inconnu'];},s=>{s.leagueDetail.extra=1;},s=>{s.leagueDetail.detailed=['urc','elite'];},s=>{s.leagueDetail.pending=[];}]){
   const copy=JSON.parse(JSON.stringify(forged));breakage(copy.state);
   const r=raw('import',{text:JSON.stringify(copy)});assert.equal(r.ok,false);assert.match(r.error,/Championnats actifs/);
  }
 }finally{if(bridge)bridge.close();fs.rmSync(root,{recursive:true,force:true});}
});
