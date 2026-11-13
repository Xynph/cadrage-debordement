'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Suivi des jeunes sans les gérer (point 11 des compléments du centre de formation, décision
// de Léo du 12/11/2026) : page « Centre de formation » en lecture seule et alertes du fil
// d'actualités. Crabos 16-17 ans (35 places), Espoirs 18-21 ans, 75 jeunes au plus.
// - crack repéré : potentiel très élevé (85 et plus, ou prodige de 15 ans), une fois par joueur ;
// - fin de contrat Espoir proche : contrat qui expire en fin de saison, ou dernière saison au
//   centre (21 ans), annoncée une fois par saison vers la fin de l'hiver ;
// - plafond de 30 matchs : alerte à 25 puis à 30 matchs, dès qu'une source de comptage est
//   branchée (chantier des compétitions de jeunes, voir connect()) ;
// - statut JIFF : annoncé par le domaine jiff (centre et licence).
// Les résultats et classements des compétitions de jeunes viennent du même branchement ; sans
// lui, la page affiche leur emplacement sans rien inventer.
function factory(){
 const CRACK=85,CAP=30,CAP_WARNINGS=[25,30],CRABOS_CAP=35,CAPACITY=75,LIMIT=300;
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b,finite=n=>typeof n==='number'&&Number.isFinite(n);
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Suivi du centre : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const active=s=>s?.academyGroupPolicy===3&&Array.isArray(s.development?.academy);
 const week=s=>s.worldMode?.week??s.franceMode?.week??s.round;
 // Vers le 1er mars : 20e des 31 semaines France, 30e des 46 semaines monde.
 const contractWeek=s=>s.franceMode?20:30;
 const academy=s=>s.development?.academy||[];
 const potentialOf=p=>finite(p.dev?.potential)?p.dev.potential:finite(p.potential)?p.potential:p.rating;
 const isCrack=p=>!!p.prodigy||potentialOf(p)>=CRACK;
 const list=names=>names.length<=1?names.join(''):names.slice(0,-1).join(', ')+' et '+names.at(-1);
 const short=(rows,max=4)=>rows.length>max?list(rows.slice(0,max).concat(`${rows.length-max} autre(s)`)):list(rows);
 const say=text=>{if(typeof news==='function')news(text);};

 // Branchement du chantier des compétitions de jeunes : connect({appearances(s,playerId),
 // summary(s)}). appearances renvoie le nombre de matchs comptés pour le plafond de 30 (ou
 // null) ; summary renvoie {competitions:[{name,standings:[{club,played,points,...}],results:[...]}]}.
 // Un objet global CDYouthCompetitions ayant la même forme est aussi reconnu.
 let provider=null;
 function connect(source){provider=source&&typeof source==='object'?source:null;return !!provider;}
 function source(){
  if(provider)return provider;
  try{return typeof CDYouthCompetitions!=='undefined'&&CDYouthCompetitions&&typeof CDYouthCompetitions==='object'?CDYouthCompetitions:null;}catch(e){return null;}
 }
 function matchCount(s,p){
  const src=source();if(!src||typeof src.appearances!=='function')return null;
  const n=src.appearances(s,p.id);return int(n,0,999)?n:null;
 }
 function competitions(s){
  const src=source(),summary=src&&typeof src.summary==='function'?src.summary(s):null;
  return object(summary)?{available:true,...copy(summary)}:{available:false};
 }
 function contracts(s){
  const out=new Map();
  for(const x of s.v78to81?.contracts||[])if(x&&id(x.id)&&int(x.expires,0,9999)&&x.expires>=s.season)out.set(x.id,Math.max(out.get(x.id)??0,x.expires));
  return out;
 }
 function jiffOf(s,p){
  if(s.jiff?.version!==1||typeof CDJiff==='undefined'||!CDJiff||typeof CDJiff.getStatus!=='function')return null;
  const e=CDJiff.getStatus(s,p.id)||[0,0,0];
  return {status:!!e[0],centreSeasons:Math.min(3,e[1]|0)};
 }
 function row(s,p,ends,previous){
  const dev=p.dev||{},start=finite(dev.seasonStart)?dev.seasonStart:p.rating,before=previous&&finite(previous[p.id])?previous[p.id]:null;
  const count=matchCount(s,p),junior=s.v73Espoirs?.minutes?.[p.id];
  return {id:p.id,name:p.name,pos:p.pos,age:p.age,group:p.age<=17?'crabos':'espoirs',rating:p.rating,potential:potentialOf(p),
   progression:{season:Math.round(p.rating-start),month:before===null?null:Math.round(p.rating-before)},
   minutes:Math.round(dev.minutes||0),appearances:dev.appearances|0,juniorMinutes:finite(junior)?Math.round(junior):null,
   injury:p.injury|0,condition:finite(p.condition)?Math.round(p.condition):null,prodigy:!!p.prodigy,crack:isCrack(p),
   contractEnd:ends.get(p.id)??null,lastSeason:p.age>=21,jiff:jiffOf(s,p),matchCap:count===null?null:{count,limit:CAP}};
 }
 function project(){
  const s=state();if(!s||!active(s))return {available:false};
  const ends=contracts(s),previous=s.academyReport?.season===s.season?s.academyReport.ratings:null;
  const players=academy(s).filter(p=>p&&id(p.id)).map(p=>row(s,p,ends,previous))
   .sort((a,b)=>(a.group===b.group?0:a.group==='crabos'?-1:1)||b.rating-a.rating||(a.id<b.id?-1:1));
  const crabos=players.filter(p=>p.group==='crabos'),espoirs=players.filter(p=>p.group==='espoirs');
  const ending=players.filter(p=>p.group==='espoirs'&&(p.contractEnd===s.season||p.lastSeason));
  const gains=players.map(p=>p.progression.season);
  return {available:true,season:s.season,week:week(s),
   crabos:{count:crabos.length,cap:CRABOS_CAP},espoirs:{count:espoirs.length},capacity:CAPACITY,total:players.length,
   summary:{injured:players.filter(p=>p.injury>0).length,cracks:players.filter(p=>p.crack).length,ending:ending.length,
    jiff:players.filter(p=>p.jiff?.status).length,progression:gains.length?Math.round(gains.reduce((a,b)=>a+b,0)/gains.length*10)/10:0,
    lastReport:s.academyReport?.season===s.season?s.academyReport.week:null},
   matchCap:{limit:CAP,warning:CAP_WARNINGS[0],connected:!!source()&&typeof source().appearances==='function'},
   competitions:competitions(s),players};
 }

 // --- Alertes du fil d'actualités -------------------------------------------------
 function ensure(s){
  if(!object(s.academyFollowUp))s.academyFollowUp={version:1,cracks:[],contractSeason:0,caps:[]};
  return s.academyFollowUp;
 }
 function alerts(s){
  if(!active(s)||s.live)return [];
  const st=ensure(s),present=new Set(academy(s).map(p=>p.id)),out=[];
  // Un joueur parti du centre n'occupe plus de place dans la mémoire des alertes.
  st.cracks=st.cracks.filter(x=>present.has(x));
  st.caps=st.caps.filter(x=>present.has(x.slice(0,x.lastIndexOf('@'))));
  const known=new Set(st.cracks),cracks=academy(s).filter(p=>id(p.id)&&!known.has(p.id)&&isCrack(p));
  if(cracks.length){
   const names=cracks.map(p=>`${p.name} (${p.pos}, ${p.age} ans)`);
   out.push(cracks.length===1?`Le responsable de la formation a repéré un crack : ${names[0]}. Son potentiel est très élevé.`
    :`Le responsable de la formation a repéré ${cracks.length} cracks au centre : ${short(names)}. Leur potentiel est très élevé.`);
   st.cracks=st.cracks.concat(cracks.map(p=>p.id)).slice(-LIMIT);
  }
  const w=week(s);
  if(Number.isSafeInteger(w)&&w>=contractWeek(s)&&st.contractSeason!==s.season){
   st.contractSeason=s.season;
   const ends=contracts(s),espoirs=academy(s).filter(p=>p.age>=18);
   const expiring=espoirs.filter(p=>ends.get(p.id)===s.season),leaving=espoirs.filter(p=>p.age>=21&&ends.get(p.id)!==s.season);
   const parts=[];
   if(expiring.length)parts.push(`contrat Espoir qui se termine en fin de saison : ${short(expiring.map(p=>p.name))}`);
   if(leaving.length)parts.push(`dernière saison au centre : ${short(leaving.map(p=>p.name))}`);
   if(parts.length)out.push('Fin de contrat proche au centre — '+parts.join(' ; ')+'. Un premier contrat pro se décide avant l’été.');
  }
  for(const p of academy(s)){
   const count=id(p.id)?matchCount(s,p):null;if(count===null)continue;
   const reached=CAP_WARNINGS.filter(t=>count>=t).at(-1);if(reached===undefined)continue;
   const key=`${p.id}@${reached}`;if(st.caps.includes(key))continue;
   st.caps=st.caps.filter(x=>!x.startsWith(p.id+'@')).concat(key).slice(-LIMIT);
   out.push(reached>=CAP?`${p.name} a atteint le plafond de ${CAP} matchs.`:`${p.name} a disputé ${count} matchs : il approche du plafond de ${CAP}.`);
  }
  for(const text of out)say(text);
  return out;
 }
 function validate(s){
  if(s?.academyFollowUp===undefined)return true;
  const x=s.academyFollowUp,ids=a=>Array.isArray(a)&&a.length<=LIMIT&&new Set(a).size===a.length;
  check(s.academyGroupPolicy===3&&shape(x,['version','cracks','contractSeason','caps'])&&x.version===1&&ids(x.cracks)&&x.cracks.every(id)&&
   int(x.contractSeason,0,s.season)&&ids(x.caps)&&x.caps.every(k=>typeof k==='string'&&/^[A-Za-z0-9:_.-]{1,180}@(25|30)$/.test(k)),'mémoire des alertes invalide');
  return true;
 }
 function execute(){throw Error('Suivi du centre : aucune commande.');}
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__academyFollowUp){
   const original=finishRound,wrapped=function(){const s=state(),result=original.apply(this,arguments);if(s&&s===state()&&!s.live&&s.phase!=='ended')alerts(s);return result;};
   Object.assign(wrapped,original);wrapped.__academyFollowUp=true;finishRound=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,alerts,connect};
}
module.exports={files,commands,factory};
