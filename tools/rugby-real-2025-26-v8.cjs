'use strict';
const fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'../modding/data06/rugby-master-2026-2027.json');
const COLLECTED=path.resolve(__dirname,'../data/scouting/performance-2025-26-v8.json');
const ROLES={
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
function normalize(s){return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().replace(/\s+/g,' ');}
const average=a=>a.reduce((s,x)=>s+x,0)/a.length;
function mergeLists(data){
 if(data.schema!=='lnr-rankings-2025-26-v8'||data.cutoff!=='2026-07-01')throw Error('Invalid data schema or cutoff');
 const merged=new Map(),conflicts=[];
 for(const list of data.lists){
  if(list.season!=='2025-2026'||!['top14','prod2'].includes(list.league)||!/^https:\/\/(top14|prod2)\.lnr\.fr\/classement\/joueurs\//.test(list.sourceUrl))throw Error('Unexpected source or season');
  for(const item of list.ranking){
   if(!item.lnrId||!item.name||!item.historicalClub)throw Error('Incomplete LNR row');
   if(Object.values(item.stats).some(x=>!Number.isFinite(x)||x<0))throw Error('Invalid numeric stats');
   const key=list.league+':'+item.lnrId;
   if(!merged.has(key))merged.set(key,{lnrId:item.lnrId,name:item.name,historicalLeague:list.league,historicalClub:item.historicalClub,historicalPosition:item.historicalPosition,stats:{},sourcePages:[]});
   const p=merged.get(key);
   if(normalize(p.name)!==normalize(item.name)||normalize(p.historicalClub)!==normalize(item.historicalClub)){conflicts.push(key);continue;}
   for(const [k,v] of Object.entries(item.stats)){
    if(p.stats[k]!==undefined&&p.stats[k]!==v){conflicts.push(key+':'+k);continue;}
    p.stats[k]=v;
   }
   p.sourcePages.push(list.sourceUrl);
  }
 }
 if(conflicts.length)throw Error('Conflicting official ranking rows: '+conflicts.join(','));
 return [...merged.values()];
}
function baselineGaps(players,overrides=new Map()){
 const roles={};
 for(const [role,attrs] of Object.entries(ROLES)){
  const g={};
  for(const lg of ['top14','prod2']){
   const v=players.filter(p=>p.league===lg&&(p.gameplayPosition||p.position)===role);
   if(!v.length)continue;
   g[lg]=average(v.map(p=>average(attrs.map(a=>overrides.get(p.id)?.[a]??p.attributesV2[a]))));
  }
  if(g.top14!=null&&g.prod2!=null)roles[role]=Math.round((g.top14-g.prod2)*100)/100;
 }
 return roles;
}
function evaluate(master,collection,{allowFixture=false}={}){
 const players=master.players;
 if(!Array.isArray(players)||(!allowFixture&&players.length!==1592))throw Error('Unexpected master size');
 const idSet=new Set(),byName=new Map();
 for(const p of players){
  if(!p.id||idSet.has(p.id))throw Error('Duplicate or missing ID');
  idSet.add(p.id);
  if(!p.attributesV2||Object.keys(p.attributesV2).length!==36)throw Error('Expected 36 attributes');
  const key=normalize(p.realName);
  if(!byName.has(key))byName.set(key,[]);
  byName.get(key).push(p);
 }
 const collected=mergeLists(collection),matches=[],unmatched=[],ambiguous=[],overrides=new Map(),seenMaster=new Set();
 let previouslyObserved=0,proMatched=0,topMatched=0;
 for(const record of collected){
  const possibilities=byName.get(normalize(record.name))||[];
  if(possibilities.length===0){unmatched.push({lnrId:record.lnrId,league:record.historicalLeague,name:record.name});continue;}
  if(possibilities.length!==1||seenMaster.has(possibilities[0].id)){ambiguous.push({lnrId:record.lnrId,name:record.name,candidates:possibilities.length});continue;}
  const p=possibilities[0];
  seenMaster.add(p.id);
  const already=p.performance2025_2026!=null||p.v4EvidenceAdjustment!=null;
  if(already)previouslyObserved++;
  const role=p.gameplayPosition||p.position;
  const metrics=record.stats,delta={};
  // An observed statistic is not itself an attribute score.
  // Only limited, declared gameplay interpretations are proposed.
  if(!already && metrics.matches>=10 && metrics.minutes>=600){
   const triesRate=metrics.tries/metrics.matches;
   if(triesRate>=.5&&['Ailier','Centre','Arrière','Numéro 8','Troisième ligne'].includes(role)){
    delta.ballCarry=2;
    if(['Ailier','Centre'].includes(role))delta.evasion=1;
   }else if(triesRate>=.3&&['Ailier','Centre','Arrière','Numéro 8','Troisième ligne'].includes(role))delta.ballCarry=1;
   if(metrics.minutes>=1500&&ROLES[role])delta.workRate=Math.max(delta.workRate||0,1); // minutes are only a proxy for coach selection
  }
  // Conversion success is a direct observed rate, unlike scoring volume; enough attempts required.
  if(!already&&metrics.conversionAttempts>=25&&metrics.conversionRate>=82&&metrics.conversionMade<=metrics.conversionAttempts&&['Demi d’ouverture','Arrière','Demi de mêlée'].includes(role))delta.goalAccuracy=1;
  const changes=[];
  for(const [attr,amount] of Object.entries(delta)){
   if(!Object.hasOwn(p.attributesV2,attr))continue;
   const from=p.attributesV2[attr],to=Math.min(97,from+amount);
   if(to>from)changes.push({attribute:attr,from,to,delta:to-from,kind:'gameplay-estimate',reason:attr==='workRate'?'high-playing-time-proxy':attr==='goalAccuracy'?'conversion-rate-over-sample':'tries-per-match-proxy'});
  }
  if(changes.length)overrides.set(p.id,Object.fromEntries(changes.map(c=>[c.attribute,c.to])));
  if(record.historicalLeague==='prod2')proMatched++;else topMatched++;
  matches.push({playerId:p.id,lnrId:record.lnrId,currentLeague:p.league,historicalLeague:record.historicalLeague,historicalClub:record.historicalClub,clubMoved:normalize(p.club)!==normalize(record.historicalClub),originalEvidenceAlreadyUsed:already,stats:metrics,sourcePages:record.sourcePages,changes});
 }
 const before=baselineGaps(players),after=baselineGaps(players,overrides);
 const reversals=Object.keys(before).filter(role=>before[role]>0&&after[role]<=0);
 if(reversals.length)throw Error('TOP14 / PROD2 mean inverted: '+reversals.join(','));
 const candidates=players.map(p=>{
  const m=matches.find(x=>x.playerId===p.id);
  return {playerId:p.id,changes:m?.changes||[],observed2025_2026:!!m,historicalLeague:m?.historicalLeague||null,estimateOnly:!!(m?.changes.length)};
 });
 return {schema:'rugby-real-v8-2025-26-candidates',cutoff:'2026-07-01',observedRows:collection.lists.reduce((n,l)=>n+l.ranking.length,0),distinctLnrEntries:collected.length,matched:matches.length,proD2Matched:proMatched,top14Matched:topMatched,alreadyObservedNoDoubleCount:previouslyObserved,unmatched,ambiguous,changedPlayers:matches.filter(x=>x.changes.length).length,changedAttributes:matches.reduce((s,x)=>s+x.changes.length,0),leagueGapBefore:before,leagueGapAfter:after,matches,candidates};
}
if(require.main===module){
 const masterPath=process.argv[2]||ROOT,sourcePath=process.argv[3]||COLLECTED,out=process.argv[4];
 const original=fs.readFileSync(masterPath,'utf8');
 const result=evaluate(JSON.parse(original),JSON.parse(fs.readFileSync(sourcePath,'utf8')));
 if(fs.readFileSync(masterPath,'utf8')!==original)throw Error('Master changed!');
 if(out)fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
 const {schema,observedRows,distinctLnrEntries,matched,proD2Matched,top14Matched,alreadyObservedNoDoubleCount,changedPlayers,changedAttributes,leagueGapBefore,leagueGapAfter,unmatched,ambiguous}=result;
 console.log(JSON.stringify({schema,observedRows,distinctLnrEntries,matched,proD2Matched,top14Matched,alreadyObservedNoDoubleCount,changedPlayers,changedAttributes,unmatched:unmatched.length,ambiguous:ambiguous.length,leagueGapBefore,leagueGapAfter}));
}
module.exports={evaluate,mergeLists,normalize,baselineGaps,ROLES};
