'use strict';
const files=Object.freeze([]),commands=Object.freeze(['player_match_history_enable']);
// The only source is the finished live match. Never infer an action from prose.
function factory(){
 const POLICY='measured-live-v1',LIMIT=40,KINDS=['try','goal','miss'];
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b,num=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Historique individuel : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S,week=s=>s.worldMode?.week??s.franceMode?.week??s.round;
 const context=s=>({season:s.season,week:week(s),club:s.club});
 const active=s=>s?.playerMatchHistory?.version===1;
 const key=m=>m.season+':'+m.week+':'+m.phase+':'+m.pair.join('-');
 const totals=(m,ci)=>m.totals.find(t=>t.clubId===ci);
 const kinds={tries:'try',penaltyGoals:'goal',penaltyMisses:'miss'};
 function individual(m,p){
  const total=totals(m,p.clubId),events=m.events.filter(e=>e.clubId===p.clubId),metrics={};
  for(const [field,kind]of Object.entries(kinds)){
   const attributed=events.filter(e=>e.kind===kind),complete=total[field]!==null&&attributed.length===total[field];
   metrics[field]=complete?attributed.filter(e=>e.playerId===p.id).length:null;
  }
  return {key:m.key,season:m.season,week:m.week,phase:m.phase,clubId:p.clubId,opponent:m.pair.find(ci=>ci!==p.clubId),minutes:p.minutes,...metrics,events:copy(events.filter(e=>e.playerId===p.id))};
 }
 function validate(s){
  if(!s||s.playerMatchHistory===undefined)return true;
  const st=s.playerMatchHistory;
  check(shape(st,['version','policy','enabled','matches'])&&st.version===1&&st.policy===POLICY&&shape(st.enabled,['season','week','club'])&&int(st.enabled.season,1,s.season)&&int(st.enabled.week,0,100)&&int(st.enabled.club,0,s.clubs.length-1)&&Array.isArray(st.matches)&&st.matches.length<=LIMIT,'schéma ou capacité invalide');
  const timestamp=(season,w)=>int(season,st.enabled.season,s.season)&&int(w,0,100)&&(season!==st.enabled.season||w>=st.enabled.week)&&(season<s.season||w<=week(s));
  check(timestamp(st.enabled.season,st.enabled.week),'activation future');
  const seen=new Set();let previous=null;
  for(const m of st.matches){
   check(shape(m,['key','season','week','phase','pair','score','duration','fixtureId','players','events','totals'])&&timestamp(m.season,m.week)&&typeof m.phase==='string'&&/^[a-z0-9-]{1,32}$/.test(m.phase)&&Array.isArray(m.pair)&&m.pair.length===2&&m.pair.every(ci=>int(ci,0,s.clubs.length-1))&&m.pair[0]!==m.pair[1]&&Array.isArray(m.score)&&m.score.length===2&&m.score.every(n=>int(n,0,1000))&&num(m.duration,0,240)&&m.duration>0&&(m.fixtureId===null||typeof m.fixtureId==='string'&&m.fixtureId.length>0&&m.fixtureId.length<=240)&&m.key===key(m)&&!seen.has(m.key),'rencontre invalide ou doublon');
   check(!previous||m.season>previous.season||m.season===previous.season&&m.week>=previous.week,'rencontres désordonnées');previous=m;seen.add(m.key);
   check(Array.isArray(m.players)&&m.players.length<=46&&Array.isArray(m.events)&&m.events.length<=1000&&Array.isArray(m.totals)&&m.totals.length===2,'feuille ou événements invalides');
   const people=new Map();
   for(const p of m.players){check(shape(p,['id','name','clubId','minutes'])&&id(p.id)&&!people.has(p.id)&&typeof p.name==='string'&&p.name.length>0&&p.name.length<=120&&!/[\u0000-\u001f\u007f]/.test(p.name)&&m.pair.includes(p.clubId)&&(p.minutes===null||num(p.minutes,0,m.duration)),'joueur ou minutes invalides');people.set(p.id,p);}
   const eventIds=new Set();let prior=-1;
   for(const e of m.events){const p=people.get(e.playerId);check(shape(e,['index','minute','kind','playerId','clubId'])&&int(e.index,0,999)&&e.index>prior&&!eventIds.has(e.index)&&num(e.minute,0,m.duration)&&KINDS.includes(e.kind)&&p&&p.clubId===e.clubId,'événement sans acteur/équipe ou index répété');prior=e.index;eventIds.add(e.index);}
   const clubs=new Set();for(const t of m.totals){check(shape(t,['clubId','tries','penaltyGoals','penaltyMisses'])&&m.pair.includes(t.clubId)&&!clubs.has(t.clubId)&&Object.keys(kinds).every(k=>t[k]===null||int(t[k],0,1000)),'totaux collectifs invalides');clubs.add(t.clubId);for(const [field,kind]of Object.entries(kinds))check(t[field]===null||m.events.filter(e=>e.clubId===t.clubId&&e.kind===kind).length<=t[field],'attribution supérieure au total collectif');}
  }
  return true;
 }
 function capture(l){
  const s=state();if(!active(s)||!l?.finished||!int(l.userSide,0,1)||l!==s.live)return false;
  const fixture=l.worldContext||l.franceContext,m={season:s.season,week:week(s),phase:fixture?.phase||s.phase,pair:l.pair.slice(),score:l.score.slice(),duration:l.minute,fixtureId:fixture?.fixtureId||fixture?.id||null,players:[],events:[],totals:[]};m.key=key(m);
  if(s.playerMatchHistory.matches.some(r=>r.key===m.key))return false;
  for(let side=0;side<2;side++){
   const sh=l.sheets[side],ci=l.pair[side];
   for(const pid of [...new Set(sh.used)]){
    const p=s.clubs[ci].players.find(p=>p.id===pid);if(!p)continue;
    const minutes=sh.minutes?.[pid];m.players.push({id:pid,name:p.name,clubId:ci,minutes:num(minutes,0,l.minute)?minutes:null});
   }
   const st=l.stats?.[side],goals=int(st?.goals,0,1000)?st.goals:null,attempts=int(st?.goalAttempts,0,1000)?st.goalAttempts:null;
   m.totals.push({clubId:ci,tries:int(l.tries?.[side],0,1000)?l.tries[side]:null,penaltyGoals:goals,penaltyMisses:goals!==null&&attempts!==null&&attempts>=goals?attempts-goals:null});
  }
  for(let i=0;i<(l.events||[]).length;i++){
   const e=l.events[i],scene=e.scene;if(!scene||!KINDS.includes(scene.kind)||!int(scene.team,0,1))continue;
   const ci=l.pair[scene.team],p=m.players.find(p=>p.id===scene.actor&&p.clubId===ci);if(!p)continue;
   m.events.push({index:i,minute:e.min,kind:scene.kind,playerId:p.id,clubId:ci});
  }
  const matches=s.playerMatchHistory.matches.concat(m).slice(-LIMIT),candidate={...s,playerMatchHistory:{...s.playerMatchHistory,matches}};
  validate(candidate);s.playerMatchHistory.matches=matches;return true;
 }
 function execute(command,p){
  const s=state();check(command==='player_match_history_enable'&&s&&shape(p,['context','confirmed'])&&p.confirmed===true&&shape(p.context,['season','week','club']),'paramètres invalides');
  check(Object.keys(context(s)).every(k=>p.context[k]===context(s)[k]),'contexte périmé');check(!s.live&&s.phase==='league'&&s.playerMatchHistory===undefined,'activation hors match en saison régulière, une seule fois');
  s.playerMatchHistory={version:1,policy:POLICY,enabled:context(s),matches:[]};return {playerMatchHistoryAction:{command}};
 }
 function project(){
  const s=state(),enabled=active(s),base={available:!!s,enabled,context:s?context(s):null,canEnable:!!s&&!s.live&&s.phase==='league'&&s.playerMatchHistory===undefined,limit:LIMIT,recordedMatches:enabled?s.playerMatchHistory.matches.length:0,players:[],notice:'Registre activé explicitement, sans reconstruction du passé. Minutes des feuilles finales ; essais et tirs de pénalité attribués par les scènes du moteur. Plaquages, passes, transformations et mètres individuels inconnus. Ratio par 80 calculé uniquement sur les rencontres dont les minutes et l’attribution sont connues.'};
  if(!enabled)return base;
  base.players=(s.clubs[s.club]?.players||[]).map(p=>{
   const matches=s.playerMatchHistory.matches.flatMap(m=>{const row=m.players.find(q=>q.id===p.id);return row?[individual(m,row)]:[];}).slice(-5).reverse();
   const measured=matches.filter(m=>m.minutes!==null),metrics={};
   for(const field of Object.keys(kinds)){
    const known=matches.filter(m=>m[field]!==null),rated=known.filter(m=>m.minutes!==null&&m.minutes>0),minutes=rated.reduce((n,m)=>n+m.minutes,0);
    metrics[field]={total:known.length?known.reduce((n,m)=>n+m[field],0):null,matches:known.length,ratioMatches:rated.length,minutes,per80:minutes>0?rated.reduce((n,m)=>n+m[field],0)*80/minutes:null};
   }
   return {id:p.id,name:p.name,pos:p.pos,matches,minutes:measured.length?measured.reduce((n,m)=>n+m.minutes,0):null,measuredMatches:measured.length,metrics,tackles:null,passes:null,conversions:null,metres:null};
  }).sort((a,b)=>b.matches.length-a.matches.length||a.name.localeCompare(b.name));return base;
 }
 function installHooks(){
  if(typeof recordDevelopmentMatch!=='function'||recordDevelopmentMatch.__measuredPlayerHistory)return true;
  const original=recordDevelopmentMatch,wrapped=function(l){const result=original.apply(this,arguments);capture(l);return result;};
  Object.assign(wrapped,original);wrapped.__measuredPlayerHistory=true;recordDevelopmentMatch=wrapped;return true;
 }
 return {project,validate,execute,installHooks,capture};
}
module.exports={files,commands,factory};
