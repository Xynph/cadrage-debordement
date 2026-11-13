'use strict';
// Mesure des matchs des jeunes sur N saisons (défaut 20) dans une carrière mondiale de 116 clubs :
// temps de simulation des matchs jeunes par saison, taille de la sauvegarde et de ses parties.
// Les effectifs pros ne jouent pas ici : seuls les centres vivent (matchs, vieillissement,
// revue du potentiel, générations du 1er juillet). Usage : node scripts/measure-youth-matches.cjs [saisons]
const {worldYouth}=require('../tests/helpers/youth-world-harness.cjs');
function measure(seasons=20,{log=console.log}={}){
 const h=worldYouth();
 h.run(`var youthMeasure=()=>{const ac=[S.development.academy,...S.aiRoster.academies.map(a=>a.players)].flat();
  const loads=ac.map(p=>p.youthLoad||[]);
  return {save:JSON.stringify(S).length,youth:JSON.stringify(S.youthMatches||{}).length,loads:JSON.stringify(loads).length,potential:JSON.stringify(S.potentialEvolution||{}).length,
   players:ac.length,history:(S.youthMatches?.history||[]).length,
   apps:ac.map(p=>p.youthLoad&&p.youthLoad[0]===S.season?p.youthLoad[1]:0),injured:ac.filter(p=>p.injury>0).length,
   avgRating:ac.reduce((n,p)=>n+p.rating,0)/ac.length,avgPotential:ac.reduce((n,p)=>n+p.dev.potential,0)/ac.length};};
 var youthYearEnd=()=>Math.floor(Date.UTC(2026+S.season,5,30)/86400000);
 var youthRollover=()=>{const done=S.season;S.season++;S.round=0;S.worldMode.week=0;
  for(const pool of [S.development.academy,...S.aiRoster.academies.map(a=>a.players)])for(const p of pool)ageDevelopmentPlayer(p,done);
  S.development.academy=S.development.academy.filter(p=>p.age<=21);for(const a of S.aiRoster.academies)a.players=a.players.filter(p=>p.age<=21);
  CDNativeAcademyGroups.afterSeason(S,S.club);CDNativeAcademyGroups.settleIntake(S);};`);
 const rows=[];
 for(let season=1;season<=seasons;season++){
  const start=process.hrtime.bigint();
  h.run('CDYouthMatches.process(S,youthYearEnd())');
  const ms=Number(process.hrtime.bigint()-start)/1e6;
  const m=JSON.parse(h.run('JSON.stringify(youthMeasure())'));
  const apps=m.apps.filter(n=>n>0).sort((a,b)=>a-b),q=f=>apps[Math.floor(f*(apps.length-1))];
  const row={season,ms:Math.round(ms),saveMB:+(m.save/1e6).toFixed(2),youthKB:+(m.youth/1e3).toFixed(1),loadsKB:+(m.loads/1e3).toFixed(1),potentialKB:+(m.potential/1e3).toFixed(1),players:m.players,history:m.history,
   p10:q(.1),median:q(.5),p90:q(.9),max:apps.at(-1),over25:apps.filter(n=>n>25).length,injured:m.injured,rating:+m.avgRating.toFixed(1),potential:+m.avgPotential.toFixed(1)};
  rows.push(row);log(JSON.stringify(row));
  h.run("nativeSystems.domain('youthMatches').validate(S);nativePotentialEvolutionValidate(S)");
  if(season<seasons)h.run('youthRollover()');
 }
 return rows;
}
if(require.main===module)measure(Number(process.argv[2])||20);
module.exports={measure};
