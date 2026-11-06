'use strict';
const fs=require('node:fs'),path=require('node:path');
const MASTER=path.resolve(__dirname,'../modding/data06/rugby-master-2026-2027.json');
const SOURCE=path.resolve(__dirname,'../data/scouting/performance-2025-26-v9.json');
const SPECIALTIES={
 'Pilier gauche':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Pilier droit':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Talonneur':['hooking','lineoutThrow','tackling','maul','ruckClearout'],
 'Deuxième ligne':['lineoutJump','lineoutLift','maul','ruckClearout','strength'],
 'Troisième ligne':['jackal','tackling','ruckClearout','workRate','ballCarry'],
 'Numéro 8':['ballCarry','strength','tackling','jackal','workRate'],
 'Demi de mêlée':['passing','decisions','vision','kickAccuracy','workRate'],
 'Demi d’ouverture':['kickAccuracy','passing','decisions','vision','kickDistance'],
 'Centre':['tackling','ballCarry','passing','offload','decisions'],
 'Ailier':['topSpeed','acceleration','evasion','receiving','kickChase'],
 'Arrière':['aerialAbility','receiving','positioning','kickDistance','decisions']
};
const FORWARDS=new Set(['Pilier gauche','Pilier droit','Talonneur','Deuxième ligne','Troisième ligne','Numéro 8']);
const normalize=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().replace(/\s+/g,' ');
const avg=a=>a.reduce((s,v)=>s+v,0)/a.length;
function mergeRankings(collection){
 if(collection.schema!=='lnr-rotation-defence-2025-26-v9'||collection.cutoff!=='2026-07-01')throw Error('Bad collection schema');
 const entries=new Map(),conflicts=[];
 for(const list of collection.lists){
  if(list.season!=='2025-2026'||!['top14','prod2'].includes(list.league)||!['minutes','cards'].includes(list.metric))throw Error('Bad season or metric');
  if(!list.sourceUrl.startsWith('https://'+list.league+'.lnr.fr/classement/joueurs/'))throw Error('Bad source URL');
  if(list.ranking.length!==20)throw Error('Ranking is not 20 rows');
  for(const row of list.ranking){
   if(!row.name||!row.lnrId||!row.historicalClub||!row.historicalPosition)throw Error('Incomplete row');
   if(Object.values(row.stats).some(v=>typeof v!=='number'||!Number.isFinite(v)||v<0))throw Error('Bad measured number');
   if(row.stats.matches!=null&&row.stats.matches>40)throw Error('Unrealistic match count');
   if(row.stats.minutes!=null&&row.stats.minutes>row.stats.matches*85)throw Error('Impossible playing minutes');
   if(row.stats.cards!=null&&row.stats.cards!==(row.stats.yellow+row.stats.orange+row.stats.red))throw Error('Incorrect card sum');
   const key=list.league+':'+row.lnrId;
   if(!entries.has(key))entries.set(key,{lnrId:String(row.lnrId),name:row.name,historicalLeague:list.league,historicalClub:row.historicalClub,historicalPosition:row.historicalPosition,stats:{},lists:[],key});
   const e=entries.get(key);
   if(normalize(e.name)!==normalize(row.name)||normalize(e.historicalClub)!==normalize(row.historicalClub)){conflicts.push(key+':identity');continue;}
   for(const [k,v] of Object.entries(row.stats)){
    if(Object.hasOwn(e.stats,k)&&e.stats[k]!==v){conflicts.push(key+':'+k);continue;}
    e.stats[k]=v;
   }
   e.lists.push(list.metric);
  }
 }
 if(conflicts.length)throw Error('Conflicting measurements: '+conflicts.join(','));
 return [...entries.values()];
}
function leagueGaps(players,changes=new Map()){
 const result={};
 for(const [role,fields] of Object.entries(SPECIALTIES)){
  const groups={top14:[],prod2:[]};
  for(const p of players)if((p.gameplayPosition||p.position)===role){
   const marks=fields.map(k=>changes.get(p.id)?.[k]??p.attributesV2[k]);
   groups[p.league].push(avg(marks));
  }
  if(groups.top14.length&&groups.prod2.length)result[role]=Math.round((avg(groups.top14)-avg(groups.prod2))*100)/100;
 }
 return result;
}
function calculate(master,collection,options={}){
 const players=master.players;
 if(!Array.isArray(players)||(!options.fixture&&players.length!==1592))throw Error('Invalid master count');
 const byName=new Map(),ids=new Set();
 for(const p of players){
  if(!p.id||ids.has(p.id))throw Error('Duplicate or absent stable ID');
  ids.add(p.id);
  if(!['top14','prod2'].includes(p.league)||!SPECIALTIES[p.gameplayPosition||p.position])throw Error('Unknown league/role');
  if(!p.attributesV2||Object.keys(p.attributesV2).length!==36||Object.values(p.attributesV2).some(v=>!Number.isFinite(v)||v<20||v>97))throw Error('Invalid 36 skills');
  const k=normalize(p.realName);
  if(!byName.has(k))byName.set(k,[]);
  byName.get(k).push(p);
 }
 const entries=mergeRankings(collection),v8=new Set(collection.v8KnownKeys||[]);
 const matches=[],unmatched=[],ambiguous=[],assigned=new Set(),updates=new Map();
 for(const entry of entries){
  const possibles=byName.get(normalize(entry.name))||[];
  if(!possibles.length){unmatched.push(entry.key);continue;}
  if(possibles.length!==1||assigned.has(possibles[0].id)){ambiguous.push(entry.key);continue;}
  const p=possibles[0];assigned.add(p.id);
  const older=p.performance2025_2026!=null||p.v4EvidenceAdjustment!=null;
  const inV8=v8.has(entry.key);
  const s=entry.stats,changes=[];
  // Selection time is only an imperfect gameplay proxy, not measured endurance.
  // Do not derive defence/discipline skill from the high-cards leaderboard.
  if(!older&&!inV8&&s.minutes>=1800&&s.matches>=20&&p.attributesV2.workRate<97)
   changes.push({attribute:'workRate',from:p.attributesV2.workRate,to:p.attributesV2.workRate+1,delta:1,quality:'gameplay-estimate',reason:'long-season-selection-proxy'});
  if(changes.length)updates.set(p.id,{workRate:changes[0].to});
  matches.push({playerId:p.id,lnrKey:entry.key,historicalLeague:entry.historicalLeague,historicalClub:entry.historicalClub,role:p.gameplayPosition||p.position,forward:FORWARDS.has(p.gameplayPosition||p.position),stats:s,statisticsObserved:true,previousV8Entry:inV8,previousV4V5Observation:older,changes});
 }
 const before=leagueGaps(players),after=leagueGaps(players,updates);
 if(Object.keys(before).some(k=>before[k]>0&&after[k]<=0))throw Error('TOP14 and PRO D2 hierarchy inverted');
 const candidates=players.map(p=>{
  const m=matches.find(x=>x.playerId===p.id);
  return {playerId:p.id,changes:m?.changes||[],knownHistoricalMinutes:m?.stats.minutes??null,knownHistoricalCards:m?.stats.cards??null,metricQuality:m?'observed-stats-and-separate-estimates':'unknown'};
 });
 return {
  schema:'rugby-real-rotation-v9-candidates',cutoff:'2026-07-01',masterCount:players.length,
  measuredRows:collection.lists.reduce((a,l)=>a+l.ranking.length,0),
  distinctEntries:entries.length,
  matched:matches.length,
  newlyMatchedEntriesBeyondV8:matches.filter(m=>!m.previousV8Entry).length,
  priorV8Overlap:matches.filter(m=>m.previousV8Entry).length,
  matchedForwards:matches.filter(m=>m.forward).length,
  matchedByHistoricalLeague:Object.fromEntries(['top14','prod2'].map(l=>[l,matches.filter(m=>m.historicalLeague===l).length])),
  matchedTimeOfPlay:matches.filter(m=>m.stats.minutes!=null).length,
  observedDisciplinaryRows:matches.filter(m=>m.stats.cards!=null).length,
  untouchedExistingEvidence:matches.filter(m=>m.previousV4V5Observation).length,
  unmatched,ambiguous,
  changedPlayers:matches.filter(m=>m.changes.length).length,changedAttributes:matches.reduce((s,m)=>s+m.changes.length,0),
  leagueGapBefore:before,leagueGapAfter:after,matches,candidates
 };
}
if(require.main===module){
 const file=process.argv[2]||MASTER,src=process.argv[3]||SOURCE,out=process.argv[4];
 const original=fs.readFileSync(file,'utf8'),report=calculate(JSON.parse(original),JSON.parse(fs.readFileSync(src,'utf8')));
 if(fs.readFileSync(file,'utf8')!==original)throw Error('Changed master');
 if(out)fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
 const {schema,masterCount,measuredRows,distinctEntries,matched,newlyMatchedEntriesBeyondV8,priorV8Overlap,matchedForwards,matchedByHistoricalLeague,matchedTimeOfPlay,observedDisciplinaryRows,untouchedExistingEvidence,unmatched,ambiguous,changedPlayers,changedAttributes,leagueGapBefore,leagueGapAfter}=report;
 console.log(JSON.stringify({schema,masterCount,measuredRows,distinctEntries,matched,newlyMatchedEntriesBeyondV8,priorV8Overlap,matchedForwards,matchedByHistoricalLeague,matchedTimeOfPlay,observedDisciplinaryRows,untouchedExistingEvidence,unmatched:unmatched.length,ambiguous:ambiguous.length,changedPlayers,changedAttributes,leagueGapBefore,leagueGapAfter}));
}
module.exports={calculate,mergeRankings,normalize,SPECIALTIES};
