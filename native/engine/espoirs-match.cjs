'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Espoirs (18-21 ans) en feuille de match des clubs de l'ordinateur.
// Réel (Top 14 2025-26) : un club utilise en moyenne 7 Espoirs différents par saison, jusqu'à 11,
// davantage pendant les fenêtres internationales (joueurs partis en sélection) et dans les
// matchs à faible enjeu. Le nombre par saison et par club est un objectif tiré par empreinte
// (moyenne 7, de 3 à 11) ; la cadence des débuts et le nombre d'Espoirs par feuille suivent
// les absences et l'enjeu. Les valeurs de cadence sont inventées (aucune donnée par match réelle).
// Mécanique : l'Espoir est prêté à l'équipe première le temps de la journée (déplacé du centre
// vers l'effectif, marqué `espoirLoan`), puis rendu au centre en fin de journée ; le moteur de
// match ne connaît que les joueurs de l'effectif. Le JIFF n'est jamais dégradé : un Espoir ne
// remplace un non-JIFF que si le compte de la feuille ne tombe pas sous l'exigence.
function factory(){
 const POLICY='espoirs-feuille-v1',TARGET_MEAN=7,Q_MIN=3,Q_MAX=11,HISTORY=12,MAX_SLOTS=4,JIFF_TARGET=16;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b,num=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Espoirs en feuille : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>16;h=Math.imul(h,2246822507);h^=h>>>13;h=Math.imul(h,3266489909);h^=h>>>16;return h>>>0;};
 const unit=x=>hash(x)/4294967296;
 const active=s=>s?.espoirsMatch?.version===1;
 const weekOf=s=>s.franceMode?.week??s.worldMode?.week??s.round??0;
 const weekKey=s=>s.season+':'+weekOf(s);
 // Semaines de saison régulière : France 30 (avec les semaines de repos du Top 14), monde ~30 journées de championnat.
 const roundsTotal=()=>30;
 function academyOf(s,clubId){
  const a=(s.aiRoster?.academies||[]).find(x=>x.clubId===clubId);return a?a.players:null;
 }
 // Objectif annuel de débutants : moyenne 7, de 3 à 11, déterministe par club et saison.
 function seasonGoal(s,clubId){
  const u=[1,2,3,4].reduce((sum,i)=>sum+unit(s.season+':'+clubId+':q'+i),0);
  return Math.max(Q_MIN,Math.min(Q_MAX,Math.round(TARGET_MEAN+(u-2)*3.4)));
 }
 function archive(st,season){
  const rows=Object.values(st.clubs);if(!rows.length)return;
  const counts=rows.map(r=>r.used.length);
  st.history=[{season,clubs:counts.length,average:Math.round(counts.reduce((a,b)=>a+b,0)/counts.length*100)/100,max:Math.max(...counts),min:Math.min(...counts)},...st.history].slice(0,HISTORY);
 }
 function ensure(s){
  if(!s.espoirsMatch)s.espoirsMatch={version:1,policy:POLICY,season:s.season,clubs:{},history:[]};
  const st=s.espoirsMatch;
  if(st.season!==s.season){archive(st,st.season);st.season=s.season;st.clubs={};}
  return st;
 }
 function row(st,s,clubId){
  return st.clubs[clubId]||(st.clubs[clubId]={q:seasonGoal(s,clubId),used:[],plan:null,sheets:0,total:0,window:0,windowTotal:0,low:0,lowTotal:0});
 }
 const isJiff=(s,p)=>typeof CDJiff!=='undefined'&&CDJiff&&CDJiff.isJiff?CDJiff.isJiff(s,p):false;
 const jiffOn=(s,c)=>typeof CDJiff!=='undefined'&&CDJiff&&s.jiff?.version===1&&CDJiff.subjectLeagues(s)&&Object.values(CDJiff.subjectLeagues(s)).some(l=>l.includes(c.id));
 // Joueurs de l'équipe première absents ce week-end : sélections (mode monde) et blessés.
 function absences(s,c){
  let released=0;
  try{
   const f=fixtureOf(s,c);
   if(f?.date&&typeof CDWorldCareer!=='undefined')released=c.players.filter(p=>!p.espoirLoan&&CDWorldCareer.clubReleaseOn(s,p.id,f.date)).length;
  }catch(e){released=0;}
  const injured=c.players.filter(p=>!p.espoirLoan&&p.injury>0).length;
  return {released,injured};
 }
 // Enjeu faible : adversaire nettement plus faible, ou club à l'abri en fin de saison.
 function lowStakes(s,c,opponent,key){
  const level=t=>{const r=t.players.map(p=>p.rating||0).sort((a,b)=>b-a).slice(0,23);return r.reduce((a,b)=>a+b,0)/Math.max(1,r.length);};
  if(!opponent)return false;
  return level(c)-level(opponent)>=3||unit(key+':stake:'+c.id)<.12;
 }
 // Rencontre de championnat de la journée pour ce club : {opponent, date} ou null (repos, coupe, phase finale).
 function fixtureOf(s,c){
  try{
   if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)){
    const f=CDWorldCareer.fixtures(s).find(x=>x.homeId===c.id||x.awayId===c.id);
    return f&&f.phase==='league'?{opponent:s.clubs[f.homeId===c.id?f.awayId:f.homeId],date:f.date}:null;
   }
   if(typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(s)){
    const f=CDFranceCompetition.currentFixtures(s).find(x=>x.pair.includes(c.id));
    return f&&f.phase==='league'?{opponent:s.clubs[f.pair[0]===c.id?f.pair[1]:f.pair[0]],date:null}:null;
   }
   const pair=(typeof roundPairs==='function'?roundPairs():[]).find(x=>x.includes(c.id));
   return pair?{opponent:s.clubs[pair[0]===c.id?pair[1]:pair[0]],date:null}:null;
  }catch(e){return null;}
 }
 // Plan de la journée pour un club : liste d'Espoirs (ids) retenus, mémorisée pour que toute
 // reconstruction de la feuille pendant la journée donne le même résultat.
 function plan(s,c){
  const st=ensure(s),key=weekKey(s),r=row(st,s,c.id);
  if(r.plan&&r.plan.key===key)return r.plan;
  const pool=academyOf(s,c.id)||[];
  const eligible=pool.filter(p=>p&&id(p.id)&&p.age>=18&&p.age<=21&&!p.injury&&Number.isFinite(p.rating)&&Number.isInteger(p.fam));
  const week=weekOf(s),remaining=Math.max(1,roundsTotal()-week);
  const fx=fixtureOf(s,c);if(!fx){r.plan={key,ids:[],window:false,low:false,pending:false};return r.plan;}
  const opp=fx.opponent,abs=absences(s,c);
  const windowWeek=abs.released>=2,low=lowStakes(s,c,opp,key);
  // Espérance d'Espoirs par feuille : base, plus les absents (sélections, blessés), plus l'enjeu faible.
  let lambda=.72+.16*Math.min(5,abs.released)*(windowWeek?1.6:1)+.1*Math.min(4,abs.injured)+(low?.55:0);
  lambda=Math.min(MAX_SLOTS,lambda);
  let k=Math.floor(lambda)+(unit(key+':k:'+c.id)<lambda-Math.floor(lambda)?1:0);
  const used=new Set(r.used),chosen=[],taken=new Set();
  const byRank=list=>list.slice().sort((a,b)=>b.rating-a.rating||(a.id<b.id?-1:1));
  for(let i=0;i<k;i++){
   const open=r.q-r.used.length-chosen.filter(x=>!used.has(x)).length;
   const usedAvailable=byRank(eligible.filter(p=>used.has(p.id)&&!taken.has(p.id)));
   const fresh=eligible.filter(p=>!used.has(p.id)&&!taken.has(p.id));
   // Cadence des débuts : rattraper l'objectif d'ici la fin de saison, plus vite en fenêtre.
   const pNew=open<=0?0:Math.min(1,(open/(remaining+1))*(windowWeek?2.4:1.35)*(low?1.3:1)+(r.used.length===0?.35:0));
   let pick=null;
   if(fresh.length&&(unit(key+':new:'+i+':'+c.id)<pNew||!usedAvailable.length)&&open>0){
    // Les nouveaux sont tirés parmi les meilleurs du centre, avec une part de hasard.
    const ranked=byRank(fresh).slice(0,Math.max(4,Math.ceil(fresh.length/3)));
    pick=ranked[hash(key+':pick:'+i+':'+c.id)%ranked.length];
   }else if(usedAvailable.length){
    pick=usedAvailable[hash(key+':again:'+i+':'+c.id)%Math.min(usedAvailable.length,6)];
   }
   if(pick){chosen.push(pick.id);taken.add(pick.id);}
  }
  r.plan={key,ids:chosen,window:windowWeek,low,pending:true};
  return r.plan;
 }
 // Prête les Espoirs du plan à l'effectif (déplacés, jamais copiés : identifiants uniques).
 function materialize(s,c,pl){
  const pool=academyOf(s,c.id);if(!pool)return [];
  const out=[];
  for(const pid of pl.ids){
   if(c.players.some(p=>p.id===pid)){out.push(pid);continue;}
   const p=pool.find(x=>x.id===pid);if(!p)continue;
   const rest=pool.filter(x=>x.id!==pid);pool.length=0;pool.push(...rest);
   p.espoirLoan=true;p.academy=false;p.contractEnd=s.season;c.players.push(p);out.push(pid);
  }
  return out;
 }
 function returnLoans(s,keepKeyFor=null,only=null){
  let n=0;
  for(const c of s.clubs){
   if(c.id===s.club||only&&!only.includes(c.id))continue;
   const loaned=c.players.filter(p=>p.espoirLoan);if(!loaned.length)continue;
   const live=s.live&&!s.live.finished&&s.live.pair?.includes(c.id);
   if(live)continue;
   const pool=academyOf(s,c.id);if(!pool)continue;
   if(keepKeyFor&&s.espoirsMatch?.clubs?.[c.id]?.plan?.key===keepKeyFor)continue;
   c.players=c.players.filter(p=>!p.espoirLoan);
   for(const p of loaned){delete p.espoirLoan;p.academy=true;p.contractEnd=null;pool.push(p);n++;}
  }
  return n;
 }
 // Remplace, sur la feuille, les joueurs les plus faibles compatibles par les Espoirs du plan.
 function inject(s,c,sheet,ids){
  const players=new Map(c.players.map(p=>[p.id,p]));
  const lineup=sheet.lineup.slice(),bench=sheet.bench.slice();
  const onSheet=new Set([...lineup,...bench].filter(Boolean));
  const jiffGuard=jiffOn(s,c);
  let jiffCount=[...onSheet].filter(x=>isJiff(s,players.get(x))).length;
  const floor=Math.min(jiffCount,JIFF_TARGET);
  const rate=p=>p?.rating||0;
  for(const pid of ids){
   if(onSheet.has(pid))continue;
   const e=players.get(pid);if(!e||e.injury)continue;
   const options=[];
   bench.forEach((x,j)=>{if(typeof benchEligible!=='function'||benchEligible(e,j))options.push({list:bench,i:j,cur:players.get(x),bench:true});});
   lineup.forEach((x,i)=>{if(typeof slotEligible!=='function'||slotEligible(e,i))options.push({list:lineup,i,cur:players.get(x),bench:false});});
   // Banc d'abord, puis XV ; on remplace le moins bon à ce poste, jamais un Espoir déjà placé.
   options.sort((a,b)=>(a.bench===b.bench?0:a.bench?-1:1)||rate(a.cur)-rate(b.cur));
   const target=options.find(o=>{
    if(o.cur&&ids.includes(o.cur.id))return false;
    if(!jiffGuard)return true;
    const drop=o.cur&&isJiff(s,o.cur)&&!isJiff(s,e)?1:0;
    return jiffCount-drop>=floor;
   });
   if(!target)continue;
   if(target.cur&&isJiff(s,target.cur))jiffCount--;
   if(isJiff(s,e))jiffCount++;
   target.list[target.i]=pid;onSheet.add(pid);
  }
  return {...sheet,lineup,bench};
 }
 function record(s,c,pl,sheet){
  // Compte à la première construction de la feuille de la journée (le plan est mémorisé).
  const st=ensure(s),r=row(st,s,c.id);
  if(!pl.pending)return;
  const sheetIds=new Set([...sheet.lineup,...sheet.bench]);
  const played=pl.ids.filter(x=>sheetIds.has(x));
  pl.pending=false;pl.ids=played;
  r.sheets++;r.total+=played.length;if(pl.window){r.window++;r.windowTotal+=played.length;}if(pl.low){r.low++;r.lowTotal+=played.length;}
  for(const x of played)if(!r.used.includes(x))r.used.push(x);
 }
 function sheetFor(s,c,sheet){
  const pl=plan(s,c);
  if(!pl.ids.length){record(s,c,pl,sheet);return sheet;}
  const ids=materialize(s,c,pl);
  const base=ids.length?inject(s,c,sheet,ids):sheet;
  record(s,c,pl,base);
  return base;
 }
 function validate(s){
  if(!s||s.espoirsMatch===undefined)return true;
  const st=s.espoirsMatch;
  check(shape(st,['version','policy','season','clubs','history'])&&st.version===1&&st.policy===POLICY&&int(st.season,1,s.season),'état invalide');
  check(object(st.clubs)&&Object.keys(st.clubs).length<=500&&Object.entries(st.clubs).every(([k,r])=>int(+k,0,s.clubs.length-1)&&
   shape(r,['q','used','plan','sheets','total','window','windowTotal','low','lowTotal'])&&int(r.q,Q_MIN,Q_MAX)&&Array.isArray(r.used)&&r.used.length<=40&&r.used.every(id)&&
   int(r.sheets,0,400)&&int(r.total,0,400*MAX_SLOTS)&&int(r.window,0,400)&&int(r.windowTotal,0,400*MAX_SLOTS)&&int(r.low,0,400)&&int(r.lowTotal,0,400*MAX_SLOTS)&&
   (r.plan===null||shape(r.plan,['key','ids','window','low','pending'])&&typeof r.plan.key==='string'&&/^\d+:\d+$/.test(r.plan.key)&&Array.isArray(r.plan.ids)&&r.plan.ids.length<=MAX_SLOTS&&r.plan.ids.every(id)&&typeof r.plan.window==='boolean'&&typeof r.plan.low==='boolean'&&typeof r.plan.pending==='boolean')),'saison par club invalide');
  check(Array.isArray(st.history)&&st.history.length<=HISTORY&&st.history.every(h=>shape(h,['season','clubs','average','max','min'])&&int(h.season,1,s.season)&&int(h.clubs,1,500)&&num(h.average,0,40)&&int(h.max,0,40)&&int(h.min,0,40)),'historique invalide');
  return true;
 }
 function project(){
  const s=state();if(!s||!active(s))return {available:false};
  const rows=Object.values(s.espoirsMatch.clubs);
  const mean=rows.length?Math.round(rows.reduce((a,r)=>a+r.used.length,0)/rows.length*100)/100:null;
  return {available:true,season:s.espoirsMatch.season,averageDistinct:mean,history:s.espoirsMatch.history.slice(0,5)};
 }
 function execute(){throw Error('Espoirs en feuille : aucune commande.');}
 // Rapport de la saison en cours ou de la dernière saison pour un club.
 function summary(s){
  if(!s?.espoirsMatch)return null;
  const rows=Object.entries(s.espoirsMatch.clubs).map(([k,r])=>({club:+k,distinct:r.used.length,sheets:r.sheets,perSheet:r.sheets?r.total/r.sheets:0,windowSheets:r.window,windowPerSheet:r.window?r.windowTotal/r.window:0,lowSheets:r.low,lowPerSheet:r.low?r.lowTotal/r.low:0}));
  return rows;
 }
 // Armé uniquement pendant la création d'un match simulé de l'ordinateur : les prêts n'existent alors
// que le temps de la simulation et sont rendus dès la fin de ce match (applyMatchInjuries).
 let armed=0;
 const worldOn=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 function withArmed(fn){armed++;try{return fn();}finally{armed--;}}
 function installHooks(){
  if(typeof buildSheet==='function'&&!buildSheet.__espoirsMatch){
   const original=buildSheet,wrapped=function(c,preferred=[],preferredBench=[]){
    const sheet=original.apply(this,arguments);const s=state();
    if(!armed||!s||!c||c.id===s.club||preferred.length||preferredBench.length||s.phase!=='league'||!worldOn(s)||!s.aiRoster?.academies?.length||!Array.isArray(s.clubs))return sheet;
    if(typeof validatingStartup!=='undefined'&&validatingStartup)return sheet;
    return sheetFor(s,c,sheet);
   };
   Object.assign(wrapped,original);wrapped.__espoirsMatch=true;buildSheet=wrapped;
  }
  if(typeof createRugbyMatch==='function'&&!createRugbyMatch.__espoirsMatch){
   const original=createRugbyMatch,wrapped=function(pair,legacy,automated){
    if(automated!==true)return original.apply(this,arguments);
    const args=arguments,self=this;
    return withArmed(()=>original.apply(self,args));
   };
   Object.assign(wrapped,original);wrapped.__espoirsMatch=true;createRugbyMatch=wrapped;
  }
  if(typeof applyMatchInjuries==='function'&&!applyMatchInjuries.__espoirsMatch){
   const original=applyMatchInjuries,wrapped=function(l){
    try{return original.apply(this,arguments);}
    finally{const s=state();if(s&&active(s)&&l?.pair)returnLoans(s,null,l.pair);}
   };
   Object.assign(wrapped,original);wrapped.__espoirsMatch=true;applyMatchInjuries=wrapped;
  }
  if(typeof finishRound==='function'&&!finishRound.__espoirsMatch){
   const original=finishRound,wrapped=function(){
    const s=state();
    try{return original.apply(this,arguments);}
    finally{if(s&&active(s)&&S===s&&!(s.live&&!s.live.finished))returnLoans(s);}
   };
   Object.assign(wrapped,original);wrapped.__espoirsMatch=true;finishRound=wrapped;
  }
  if(typeof advanceSeason==='function'&&!advanceSeason.__espoirsMatch){
   const original=advanceSeason,wrapped=function(){const s=state();if(s&&active(s))returnLoans(s);return original.apply(this,arguments);};
   Object.assign(wrapped,original);wrapped.__espoirsMatch=true;advanceSeason=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,withArmed,plan,sheetFor,returnLoans,summary,seasonGoal,ensure,absences};
}
module.exports={files,commands,factory};
