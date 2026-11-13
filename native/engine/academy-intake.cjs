'use strict';
const files=Object.freeze([]),commands=Object.freeze(['academy_intake_confirm']);
// Nouvelle génération du 1er juillet (décision de Léo du 12/11/2026) : le club joué choisit
// les jeunes qu'il garde en Crabos et, si besoin, libère d'abord des Crabos pour faire de la
// place. La génération elle-même est produite par CDNativeAcademyGroups (politique 3).
function factory(){
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const check=(ok,message)=>{if(!ok)throw Error('Nouvelle génération : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const week=s=>s.worldMode?.week??s.franceMode?.week??s.round;
 const context=s=>({season:s.season,week:week(s),club:s.club});
 const groups=()=>typeof CDNativeAcademyGroups==='undefined'?null:CDNativeAcademyGroups;
 function project(){
  const s=state(),g=groups();if(!s||!g)return {available:false};
  const intake=g.intakeProject(s);
  return intake?{available:true,context:context(s),...intake}:{available:false};
 }
 function execute(command,payload){
  const s=state(),g=groups();check(s&&g,'carrière absente');
  check(command==='academy_intake_confirm'&&shape(payload,['context','confirmed','keep','release'])&&shape(payload.context,['season','week','club'])&&payload.confirmed===true,'commande ou paramètres invalides');
  const now=context(s);check(Object.keys(now).every(k=>payload.context[k]===now[k]),'contexte périmé');
  check(!s.live,'attendez la fin du match');
  const before=JSON.stringify({academy:s.development.academy,intake:s.academyIntake});
  try{const result=g.confirmIntake(s,payload.keep,payload.release);return {academyIntake:result};}
  catch(error){const saved=JSON.parse(before);s.development.academy=saved.academy;if(saved.intake===undefined)delete s.academyIntake;else s.academyIntake=saved.intake;throw error;}
 }
 // Pronostic du responsable de la formation, environ trois mois avant l'arrivée de la
 // génération (vers le 1er avril : 24e des 31 semaines France, 34e des 46 semaines monde).
 const forecastWeek=s=>s.franceMode?24:34;
 function forecast(s){
  if(s.academyGroupPolicy!==3||s.live||week(s)<forecastWeek(s)||s.academyIntakeForecast===s.season)return false;
  s.academyIntakeForecast=s.season;
  const club=s.clubs[s.club],weight=typeof academyRecruitmentWeight==='function'&&club?academyRecruitmentWeight(club):2;
  const label=weight>=4?'très prometteuse':weight>=2.5?'prometteuse':weight>=1?'dans la moyenne':'modeste';
  if(typeof news==='function')news(`Le responsable de la formation annonce la génération de l'été : ${label}. Les jeunes arriveront au début de la saison prochaine.`);
  return true;
 }
 // Rapport mensuel du responsable de la formation (toutes les 4 semaines) : jeunes en
 // progrès, jeunes au niveau du groupe pro, blessures longues. Les notes du dernier rapport
 // servent de référence pour mesurer les progrès.
 const REPORT_EVERY=4;
 function report(s){
  if(s.academyGroupPolicy!==3||s.live)return false;
  const w=week(s);if(!Number.isSafeInteger(w)||w<=0||w%REPORT_EVERY)return false;
  const previous=s.academyReport?.season===s.season?s.academyReport.ratings:null;
  if(s.academyReport?.season===s.season&&s.academyReport.week===w)return false;
  const academy=s.development?.academy||[],pros=s.clubs?.[s.club]?.players||[];
  const weakest=fam=>{const r=pros.filter(p=>p.fam===fam).map(p=>p.rating);return r.length?Math.min(...r):Infinity;};
  const rising=previous?academy.filter(p=>Number.isFinite(previous[p.id])&&p.rating-previous[p.id]>=2).sort((a,b)=>(b.rating-previous[b.id])-(a.rating-previous[a.id])||(a.id<b.id?-1:1)).slice(0,3):[];
  const ready=academy.filter(p=>p.age>=18&&!p.injury&&p.rating>=weakest(p.fam)-2).sort((a,b)=>b.rating-a.rating||(a.id<b.id?-1:1)).slice(0,3);
  const hurt=academy.filter(p=>p.injury>=4).slice(0,3);
  s.academyReport={season:s.season,week:w,ratings:Object.fromEntries(academy.map(p=>[p.id,p.rating]))};
  const parts=[];
  if(rising.length)parts.push('en progrès : '+rising.map(p=>`${p.name} (+${p.rating-previous[p.id]})`).join(', '));
  if(ready.length)parts.push('au niveau du groupe pro : '+ready.map(p=>`${p.name} (${p.pos})`).join(', '));
  if(hurt.length)parts.push('blessés longue durée : '+hurt.map(p=>`${p.name} (${p.injury} sem.)`).join(', '));
  if(!parts.length)return true;
  if(typeof news==='function')news('Rapport du responsable de la formation — '+parts.join(' ; ')+'.');
  return true;
 }
 // La validation de la génération appartient à CDNativeAcademyGroups.
 function validate(s){
  if(s?.academyIntakeForecast!==undefined)check(s.academyGroupPolicy===3&&Number.isSafeInteger(s.academyIntakeForecast)&&s.academyIntakeForecast>=1&&s.academyIntakeForecast<=s.season,'pronostic invalide');
  if(s?.academyReport!==undefined){
   const r=s.academyReport;
   check(s.academyGroupPolicy===3&&shape(r,['season','week','ratings'])&&Number.isSafeInteger(r.season)&&r.season>=1&&r.season<=s.season&&Number.isSafeInteger(r.week)&&r.week>=1&&r.week<=60&&object(r.ratings)&&Object.keys(r.ratings).length<=75&&Object.entries(r.ratings).every(([k,v])=>/^[\w:-]{1,80}$/.test(k)&&Number.isFinite(v)&&v>=0&&v<=99),'rapport de formation invalide');
  }
  return true;
 }
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__academyIntake){
   // Sans décision avant la première journée, le responsable de la formation choisit.
   const original=finishRound,wrapped=function(){const s=state(),g=groups();if(s&&g&&!s.live){if(s.phase==='league')g.settleIntake(s);forecast(s);}const result=original.apply(this,arguments);if(s&&s===state()&&!s.live&&s.phase!=='ended')report(s);return result;};
   Object.assign(wrapped,original);wrapped.__academyIntake=true;finishRound=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,forecast,report};
}
module.exports={files,commands,factory};
