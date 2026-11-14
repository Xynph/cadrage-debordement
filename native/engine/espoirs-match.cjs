'use strict';
const files=Object.freeze([]),commands=Object.freeze(['espoir_appeler','espoir_rendre']);
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
 // Rapport de la saison en cours ou de la dernière saison pour un club.
 function summary(s){
  if(!s?.espoirsMatch)return null;
  const rows=Object.entries(s.espoirsMatch.clubs).map(([k,r])=>({club:+k,distinct:r.used.length,sheets:r.sheets,perSheet:r.sheets?r.total/r.sheets:0,windowSheets:r.window,windowPerSheet:r.window?r.windowTotal/r.window:0,lowSheets:r.low,lowPerSheet:r.low?r.lowTotal/r.low:0}));
  return rows;
 }

 // ===== Club du joueur : appel d'un Espoir pour compléter la feuille (décision de Léo du 14/11/2026) =====
 // Quand l'effectif pro ne suffit pas à compléter la feuille de 23 (pilier de remplacement introuvable, blessés,
 // sélections), le staff cherche d'abord le meilleur jeune du centre apte au poste : 18 ans au moins, non blessé,
 // note au poste d'au moins 40, de préférence JIFF quand la feuille est sous l'exigence. Le jeune est prêté à
 // l'équipe première pour ce match (même mécanique et même marqueur `espoirLoan` que les clubs de l'ordinateur :
 // il quitte la liste du centre, `academy` passe à false), puis rendu au centre à la clôture de la journée. Aucun
 // contrat, aucune promotion : sans jeune apte, la feuille reste incomplète (match à 22 quand la règle le permet).
 const OWN_MIN_AGE=18,OWN_MIN_NOTE=40,OWN_MAX=4;
 let ownOff=0;
 const rewarded=new WeakSet();
 const ownWorld=s=>!!s&&s===state()&&Array.isArray(s.development?.academy)&&worldOn(s)&&Array.isArray(s.lineup)&&Array.isArray(s.reserves);
 const ownRegistered=s=>typeof CDWorldJapanQuota!=='undefined'&&CDWorldJapanQuota.activeClub&&CDWorldJapanQuota.activeClub(s,s.club);
 const slotOk=(p,slot)=>slot<15?slotEligible(p,slot):benchEligible(p,slot-15);
 const noteAt=(p,slot)=>typeof nativePositionAptitudes!=='undefined'?nativePositionAptitudes.rating(p,slot):(p.rating||0);
 const slotLabel=slot=>slot<15?POS[slot]:BENCH_LABELS[slot-15];
 const slotNumber=slot=>typeof nativePositionAptitudes!=='undefined'?nativePositionAptitudes.positionNumber(slot):slot+1;
 // Marqueur de prêt du club du joueur : identifiant de la rencontre pour laquelle le jeune est appelé (texte compact) ;
 // le jeune est rendu au centre dès que cette rencontre est passée. Les clubs de l'ordinateur posent simplement `true`.
 const ownFixtureId=s=>{try{return CDWorldCareer.userFixture(s)?.id??null;}catch(e){return null;}};
 let inReturn=false;
 const callable=(s,p)=>!!p&&id(p.id)&&!p.espoirLoan&&p.age>=OWN_MIN_AGE&&!(p.injury>0);
 // Places restant vides après le travail du staff sur la feuille actuelle (copie : aucun effet de bord).
 function repairedVacancies(s){
  const own=s.clubs[s.club],team={...own,players:own.players.map(p=>({...p}))};
  const sheet=buildSheet(team,s.lineup,s.reserves);
  return sheet.lineup.concat(sheet.bench).flatMap((x,i)=>x?[]:[i]);
 }
 function ownCandidates(s,slot,taken,wantJiff){
  const out=[];
  for(const p of s.development.academy){
   if(!callable(s,p)||taken.has(p.id)||!slotOk(p,slot))continue;
   const note=noteAt(p,slot);if(!(note>=OWN_MIN_NOTE))continue;
   out.push({p,slot,note,jiff:isJiff(s,p),value:note*(.5+(p.condition??100)*.005)});
  }
  return out.sort((a,b)=>(wantJiff?Number(b.jiff)-Number(a.jiff):0)||b.value-a.value||(a.p.id<b.p.id?-1:1));
 }
 // Meilleur jeune par place vide (jamais le même deux fois), places rares d'abord ; la règle JIFF guide le choix.
 function propose(s,slots){
  const own=s.clubs[s.club],byId=new Map(own.players.map(p=>[p.id,p]));
  const jOn=jiffOn(s,own),onSheet=s.lineup.concat(s.reserves).filter(x=>x&&byId.has(x));
  let jiffCount=jOn?onSheet.filter(x=>isJiff(s,byId.get(x))).length:0;
  const order=slots.slice(0,OWN_MAX).map(slot=>({slot,n:ownCandidates(s,slot,new Set(),false).length})).sort((a,b)=>a.n-b.n||a.slot-b.slot).map(x=>x.slot);
  const taken=new Set(),picks=[],options=new Map();
  for(const slot of order){
   const wantJiff=jOn&&jiffCount<JIFF_TARGET,list=ownCandidates(s,slot,taken,wantJiff);
   options.set(slot,list);
   if(!list.length)continue;
   taken.add(list[0].p.id);picks.push(list[0]);if(list[0].jiff)jiffCount++;
  }
  picks.sort((a,b)=>a.slot-b.slot);
  return {picks,options};
 }
 const rowOf=(s,c)=>({id:c.p.id,name:c.p.name,age:c.p.age,pos:c.p.pos,rating:c.p.rating,note:Math.round(c.note),condition:Math.round(c.p.condition??100),jiff:c.jiff});
 // Offre publiée dans le modèle (selection.espoirs) : places vides, jeune proposé par défaut et alternatives.
 function offers(s){
  if(!ownWorld(s)||s.live||s.phase==='ended'||ownRegistered(s))return null;
  const slots=repairedVacancies(s);if(!slots.length)return null;
  const {picks,options}=propose(s,slots);
  const proposed=new Map(picks.map(c=>[c.slot,c.p.id]));
  const rows=slots.slice(0,OWN_MAX).map(slot=>({slot,number:slotNumber(slot),label:slotLabel(slot),proposedId:proposed.get(slot)??null,
   candidates:(options.get(slot)||[]).slice(0,3).map(c=>rowOf(s,c))}));
  return picks.length?{minAge:OWN_MIN_AGE,slots:rows,available:true}:null;
 }
 function loanOut(s,p){
  const pool=s.development.academy,at=pool.indexOf(p);if(at<0)throw Error('Espoir introuvable au centre.');
  pool.splice(at,1);p.espoirLoan=ownFixtureId(s)||true;p.academy=false;p.contractEnd=s.season;s.clubs[s.club].players.push(p);
 }
 // Rend au centre les jeunes appelés : `which` = 'all' (tous), 'unused' (hors feuille) ou 'stale' (rencontre passée) ;
 // jamais pendant leur match.
 function returnOwn(s,which='unused'){
  if(!ownWorld(s)||inReturn)return 0;
  if(which===true)which='all';
  const own=s.clubs[s.club],sheet=new Set(s.lineup.concat(s.reserves).filter(Boolean)),now=ownFixtureId(s);
  const back=own.players.filter(p=>p.espoirLoan&&(which==='all'||(which==='stale'?typeof p.espoirLoan==='string'&&p.espoirLoan!==now:!sheet.has(p.id))));
  if(!back.length)return 0;
  if(s.live&&!s.live.finished&&s.live.pair?.includes(s.club))return 0;
  inReturn=true;
  try{
   const gone=new Set(back.map(p=>p.id));
   own.players=own.players.filter(p=>!gone.has(p.id));
   for(const p of back){delete p.espoirLoan;p.academy=true;delete p.contractEnd;s.development.academy.push(p);}
   let changed=false;
   s.lineup=s.lineup.map(x=>gone.has(x)?(changed=true,null):x);s.reserves=s.reserves.map(x=>gone.has(x)?(changed=true,null):x);
   if(changed&&!s.live&&typeof repairSheet==='function')repairSheet();
  }finally{inReturn=false;}
  return back.length;
 }
 function placeOwn(s,pairs){
  for(const {slot,p} of pairs){
   loanOut(s,p);
   if(slot<15)s.lineup[slot]=p.id;else s.reserves[slot-15]=p.id;
  }
 }
 // Commande : { assignments: [{ slot, playerId }] } — appelle les jeunes choisis sur les places vides de la feuille.
 function callUp(s,assignments){
  check(ownWorld(s)&&!s.live&&s.phase!=='ended','appel impossible pendant le match ou après la saison');
  check(!ownRegistered(s),'ce club inscrit ses joueurs : aucun appel');
  check(Array.isArray(assignments)&&assignments.length>=1&&assignments.length<=OWN_MAX&&assignments.every(a=>shape(a,['slot','playerId'])&&int(a.slot,0,22)&&id(a.playerId)),'places invalides');
  returnOwn(s);
  check(ownFixtureId(s)!==null,'aucune rencontre à préparer');
  const vacant=new Set(repairedVacancies(s));
  check(new Set(assignments.map(a=>a.slot)).size===assignments.length&&new Set(assignments.map(a=>a.playerId)).size===assignments.length,'doublon');
  const pairs=assignments.map(a=>{
   check(vacant.has(a.slot),'la place '+(a.slot+1)+' n’est pas vide');
   const p=s.development.academy.find(x=>x.id===a.playerId);
   check(callable(s,p)&&slotOk(p,a.slot)&&noteAt(p,a.slot)>=OWN_MIN_NOTE,'jeune indisponible ou inapte à ce poste');
   return {slot:a.slot,p};
  });
  // La feuille actuelle est conservée : un titulaire déjà placé ne bouge pas ; seules les places vides se remplissent.
  const before=s.lineup.concat(s.reserves),sheet=buildSheet(s.clubs[s.club],before.slice(0,15),before.slice(15));
  s.lineup=sheet.lineup;s.reserves=sheet.bench;
  placeOwn(s,pairs);
  return {espoirAppele:pairs.map(({slot,p})=>({slot,playerId:p.id,name:p.name}))};
 }
 function release(s,playerId){
  check(ownWorld(s)&&!s.live,'retour impossible pendant le match');
  const own=s.clubs[s.club],p=own.players.find(x=>x.id===playerId&&x.espoirLoan);check(p,'jeune non appelé');
  s.lineup=s.lineup.map(x=>x===playerId?null:x);s.reserves=s.reserves.map(x=>x===playerId?null:x);
  return {espoirRendu:{playerId,returned:returnOwn(s)}};
 }
 // Composition automatique du staff : la feuille est d'abord faite avec les seuls pros (sélection habituelle, règle
 // JIFF comprise) ; chaque place restée vide reçoit ensuite le meilleur jeune apte du centre. Le jeune ne déplace
 // jamais un pro déjà retenu : il comble seulement le trou, comme en vrai.
 function completeOwn(s){
  if(!ownWorld(s)||ownOff||s.live||s.phase!=='league'||ownRegistered(s)||typeof nextMatch!=='function'||!nextMatch())return false;
  returnOwn(s);
  const slots=s.lineup.concat(s.reserves).flatMap((x,i)=>x?[]:[i]);if(!slots.length)return false;
  const {picks}=propose(s,slots);if(!picks.length)return false;
  placeOwn(s,picks.map(c=>({slot:c.slot,p:c.p})));
  return true;
 }
 // Match délégué avec « Appeler un espoir » alors que la composition reste au joueur : on remplit seulement les places vides.
 function callUpProposed(s){
  if(!ownWorld(s)||ownOff||s.live||s.phase==='ended'||ownRegistered(s))return [];
  returnOwn(s);
  const slots=repairedVacancies(s);if(!slots.length)return [];
  const {picks}=propose(s,slots);if(!picks.length)return [];
  const before=s.lineup.concat(s.reserves),sheet=buildSheet(s.clubs[s.club],before.slice(0,15),before.slice(15));
  s.lineup=sheet.lineup;s.reserves=sheet.bench;
  placeOwn(s,picks.map(c=>({slot:c.slot,p:c.p})));
  return picks.map(c=>c.p.id);
 }
 function setOff(on){ownOff=Math.max(0,ownOff+(on?1:-1));}
 // Fin du match : expérience et moral du jeune appelé, puis une ligne dans le fil d'actualité.
 function rewardOwn(s,l){
  if(!ownWorld(s)||!l||rewarded.has(l)||!l.pair?.includes(s.club)||l.userSide===undefined||l.userSide<0)return;
  rewarded.add(l);
  const side=l.userSide,sh=l.sheets?.[side];if(!sh)return;
  for(const p of s.clubs[s.club].players){
   if(!p.espoirLoan)continue;
   const minutes=sh.minutes?.[p.id]||0;if(!minutes)continue;
   if(typeof growPlayer==='function'&&typeof ageGrowth==='function'){try{growPlayer(p,.1*ageGrowth(p),false);}catch(e){/* progression facultative */}}
   if(p.satisfaction&&typeof p.satisfaction.score==='number')p.satisfaction.score=Math.min(100,p.satisfaction.score+4);
   if(typeof news==='function')news(`${p.name}, appelé du centre de formation, a disputé ${Math.round(minutes)} minutes avec l’équipe première : de l’expérience et de la confiance.`);
  }
 }
 function execute(command,payload){
  const s=state();
  if(command==='espoir_appeler')return callUp(s,payload?.assignments);
  if(command==='espoir_rendre'){check(object(payload)&&id(payload.playerId),'jeune invalide');return release(s,payload.playerId);}
  throw Error('Espoirs en feuille : commande inconnue.');
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
  if(typeof autoLineup==='function'&&!autoLineup.__espoirsOwn){
   const original=autoLineup,wrapped=function(){
    const s=state();
    // Les jeunes déjà appelés pour la feuille précédente retournent au centre : la sélection repart des seuls pros.
    if(ownWorld(s)&&!s.live)returnOwn(s,'all');
    const result=original.apply(this,arguments);
    try{completeOwn(s);}catch(e){returnOwn(s,'all');throw e;}
    return result;
   };
   Object.assign(wrapped,original);wrapped.__espoirsOwn=true;autoLineup=wrapped;
  }
  if(typeof applyMatchInjuries==='function'&&!applyMatchInjuries.__espoirsOwn){
   const original=applyMatchInjuries,wrapped=function(l){
    const result=original.apply(this,arguments);
    try{rewardOwn(state(),l);}catch(e){/* récompense facultative */}
    return result;
   };
   Object.assign(wrapped,original);wrapped.__espoirsOwn=true;applyMatchInjuries=wrapped;
  }
  if(typeof finishRound==='function'&&!finishRound.__espoirsOwn){
   const original=finishRound,wrapped=function(){
    const s=state();
    try{return original.apply(this,arguments);}
    finally{if(s&&S===s&&!(s.live&&!s.live.finished))returnOwn(s,'stale');}
   };
   Object.assign(wrapped,original);wrapped.__espoirsOwn=true;finishRound=wrapped;
  }
  if(typeof advanceSeason==='function'&&!advanceSeason.__espoirsOwn){
   const original=advanceSeason,wrapped=function(){const s=state();if(s)returnOwn(s,'all');return original.apply(this,arguments);};
   Object.assign(wrapped,original);wrapped.__espoirsOwn=true;advanceSeason=wrapped;
  }
  // La clôture de la semaine (calendrier journalier) ne passe pas par finishRound : elle finit par repairSheet, hors match.
  if(typeof repairSheet==='function'&&!repairSheet.__espoirsOwn){
   const original=repairSheet,wrapped=function(){
    const s=state();if(ownWorld(s)&&!s.live)returnOwn(s,'stale');
    return original.apply(this,arguments);
   };
   Object.assign(wrapped,original);wrapped.__espoirsOwn=true;repairSheet=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,withArmed,plan,sheetFor,returnLoans,summary,seasonGoal,ensure,absences,offers,callUp,callUpProposed,returnOwn,setOff,completeOwn};
}
module.exports={files,commands,factory};
