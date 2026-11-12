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
 // La validation de la génération appartient à CDNativeAcademyGroups.
 function validate(s){
  if(s?.academyIntakeForecast!==undefined)check(s.academyGroupPolicy===3&&Number.isSafeInteger(s.academyIntakeForecast)&&s.academyIntakeForecast>=1&&s.academyIntakeForecast<=s.season,'pronostic invalide');
  return true;
 }
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__academyIntake){
   // Sans décision avant la première journée, le responsable de la formation choisit.
   const original=finishRound,wrapped=function(){const s=state(),g=groups();if(s&&g&&!s.live){if(s.phase==='league')g.settleIntake(s);forecast(s);}return original.apply(this,arguments);};
   Object.assign(wrapped,original);wrapped.__academyIntake=true;finishRound=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,forecast};
}
module.exports={files,commands,factory};
