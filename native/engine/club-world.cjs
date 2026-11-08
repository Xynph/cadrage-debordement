'use strict';
module.exports={files:['interclub-world-v124-v130.js'],commands:[],factory:function nativeClubWorld(){
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const integer=(x,a=0,b=1000000)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const text=(x,max=200)=>typeof x==='string'&&x.length>0&&x.length<=max&&!/[\u0000-\u001f]/.test(x);
 const check=(ok,what)=>{if(!ok)throw Error('Monde interclubs incohérent : '+what+'.');};
 const keys=(x,allowed)=>object(x)&&Object.keys(x).every(k=>allowed.includes(k));
 const phases=['league','barrage','semi','final','access'];
 const copy=x=>JSON.parse(JSON.stringify(x));
 function validate(s){
  if(!s||s.interclubWorld===undefined)return true;
  const w=s.interclubWorld,clubs=new Set(s.clubs.map(c=>c.id)),club=x=>clubs.has(x),season=x=>integer(x,1,s.season);
  check(keys(w,['version','pairs','coaches','events','years','lastSeason','observedSeason','seen','seasonMatches'])&&w.version===1&&object(w.pairs)&&Object.keys(w.pairs).length<=clubs.size*(clubs.size-1)/2&&object(w.coaches)&&Object.keys(w.coaches).length<=clubs.size&&Array.isArray(w.events)&&w.events.length<=140&&Array.isArray(w.years)&&w.years.length<=20&&integer(w.lastSeason,0,s.season-1),'version/collections');
  for(const [key,p] of Object.entries(w.pairs)){
   check(keys(p,['a','b','games','winsA','winsB','draws','tension','years','lastWinner','lastSeason'])&&club(p.a)&&club(p.b)&&p.a<p.b&&key===p.a+':'+p.b&&integer(p.games,1)&&integer(p.winsA)&&integer(p.winsB)&&integer(p.draws)&&p.games===p.winsA+p.winsB+p.draws&&integer(p.tension,0,100)&&Array.isArray(p.years)&&p.years.length>=1&&p.years.length<=20&&p.years.every((x,i)=>season(x)&&(!i||x>p.years[i-1]))&&p.lastSeason===p.years.at(-1)&&(p.lastWinner===null||[p.a,p.b].includes(p.lastWinner)),'face-à-face');
  }
  for(const [key,c] of Object.entries(w.coaches))check(keys(c,['clubId','style','pressure','consecutiveLosses','season','lastReaction','lastRound'])&&key===String(c.clubId)&&club(c.clubId)&&['Analytique','Prudent','Combattif','Protecteur','Exigeant'].includes(c.style)&&integer(c.pressure,0,100)&&integer(c.consecutiveLosses,0,20)&&season(c.season)&&text(c.lastReaction,400)&&integer(c.lastRound,0,34),'banc simulé');
  const seen=new Set();for(const e of w.events){
   check(keys(e,['id','season','round','phase','fixtureId','week','leagueId','a','b','home','away','winner','type','tension','clubId','reaction','pressure','close','upset'])&&text(e.id)&&!seen.has(e.id)&&season(e.season)&&integer(e.round,0,34)&&phases.includes(e.phase)&&club(e.a)&&club(e.b)&&e.a!==e.b&&integer(e.home,0,250)&&integer(e.away,0,250)&&(e.winner===null||[e.a,e.b].includes(e.winner))&&['surprise','rivalite','large_ecart','nul','rencontre'].includes(e.type)&&integer(e.tension,0,100)&&club(e.clubId)&&text(e.reaction,400)&&integer(e.pressure,0,100)&&typeof e.close==='boolean'&&typeof e.upset==='boolean','résultat');
   if(e.fixtureId!==undefined)check(text(e.fixtureId)&&e.id===e.season+':'+e.fixtureId&&integer(e.week,0,33)&&['elite','accession','access'].includes(e.leagueId),'identité France');
   seen.add(e.id);
  }
  let previous=0;for(const y of w.years){check(keys(y,['season','matches','mostIntense','rivalries'])&&season(y.season)&&y.season>previous&&y.season<=w.lastSeason&&integer(y.matches,0,600)&&integer(y.rivalries,0,435)&&(y.mostIntense===null||Object.hasOwn(w.pairs,y.mostIntense)),'archive saisonnière');previous=y.season;}
  // Les premières sauvegardes web n’avaient pas de registre de déduplication.
  // S’il est présent, son intégrité est requise ; aucune migration en lecture.
  if(w.observedSeason!==undefined||w.seen!==undefined||w.seasonMatches!==undefined){
   check(integer(w.observedSeason,0,s.season)&&Array.isArray(w.seen)&&w.seen.length<=600&&new Set(w.seen).size===w.seen.length&&w.seen.every(x=>text(x)&&x.startsWith(w.observedSeason+':'))&&integer(w.seasonMatches,0,600)&&w.seasonMatches===w.seen.length,'registre des rencontres');
  }
  return true;
 }
 function project(){
  if(!S)return null;const w=CDInterclubWorld.state(S);
  const france=typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S);
  const archives=france?S.franceMode.yearbook.map(y=>({season:y.season,champions:y.champions.map((clubId,i)=>({leagueId:i?'accession':'elite',clubId})),movement:copy(y.movement)})):(S.worldManagement?.yearbook||[]).map(y=>copy(y));
  return {events:copy(w.events).reverse(),pairs:copy(Object.values(w.pairs)).sort((a,b)=>b.tension-a.tension||b.games-a.games||a.a-b.a||a.b-b.b),coaches:copy(Object.values(w.coaches)),years:copy(w.years).reverse(),archives,notice:'Scores et confrontations issus des rencontres enregistrées dans cette carrière. Tension, styles, pression et réactions des bancs sont des récits fictifs. Aucun passé antérieur à la carrière n’est reconstitué.'};
 }
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  const prior=worldRecordResult;worldRecordResult=function(r){
   const out=prior.apply(this,arguments);
   if(S&&r&&S.history.some(h=>r.franceContext?.fixtureId?h.fixtureId===r.franceContext.fixtureId:h.round===S.round&&h.phase===S.phase&&h.pair[0]===r.pair[0]&&h.pair[1]===r.pair[1]&&h.score[0]===r.score[0]&&h.score[1]===r.score[1]))CDInterclubWorld.accept(S,r);
   return out;
  };
  const priorSeason=worldNewSeason;worldNewSeason=function(){const out=priorSeason.apply(this,arguments);if(S)CDInterclubWorld.season(S,S.season-1);return out;};return true;
 }
 function execute(){throw Error('Le monde observe les résultats ; aucune commande de score.');}
 return {project,validate,execute,installHooks};
}};
