'use strict';
const academyGroups=require('./academy-groups.cjs');
// Closed production manifest. Each domain owns its rules and strict validator;
// the worker remains the only disk transaction and save authority.
const domains={clubMeetings:require('./club-meetings.cjs'),matchTalks:require('./match-talks.cjs'),sceneInvitations:require('./scene-invitations.cjs'),playerMatchHistory:require('./player-match-history.cjs'),staffEmployment:require('./staff-employment.cjs'),customCompetition:require('./custom-competition.cjs'),interclubMarket:require('./interclub-market.cjs'),staffMentoring:require('./staff-mentoring.cjs'),performanceAnalysis:require('./performance-analysis.cjs'),press:require('./press.cjs'),relationships:require('./relationships.cjs'),clubWorld:require('./club-world.cjs'),academyPathways:require('./academy.cjs'),clubStrategy:require('./club-strategy.cjs'),clubSupport:require('./club-support.cjs'),managerCareer:require('./manager-career.cjs'),playbook:require('./playbook.cjs'),coachNotebook:require('./coach-notes.cjs'),staffCareer:require('./staff-career.cjs'),regenScouting:require('./regen-scouting.cjs'),youthDevelopment:require('./youth-development.cjs'),academyIntake:require('./academy-intake.cjs'),jiff:require('./jiff.cjs'),formationFees:require('./formation-fees.cjs'),academyFollowUp:require('./academy-follow-up.cjs'),leagueDetail:require('./league-detail.cjs')};
const files=Object.freeze([...new Set(Object.values(domains).flatMap(d=>d.files))]);
const commands=Object.freeze(Object.values(domains).flatMap(d=>d.commands));
if(new Set(commands).size!==commands.length)throw Error('Commandes natives de domaine en double.');
function bootstrap(){
 const definitions=Object.entries(domains).map(([key,d])=>JSON.stringify(key)+':('+d.factory.toString()+')()').join(',');
 return `const nativeStaffCareerSources=(()=>{const freeze=value=>{if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;};return freeze(typeof nativeStaffCareerSourcesText==='string'?JSON.parse(nativeStaffCareerSourcesText):{});})();
 let nativeStaffTransition=null;
 const nativeSystems=(()=>{
  const domains={${definitions}},owners=new Map();
  ${Object.entries(domains).map(([key,d])=>d.commands.map(c=>`owners.set(${JSON.stringify(c)},domains[${JSON.stringify(key)}]);`).join('')).join('')}
  return {
   domain(id){return domains[id]||null;},
   project(){return S?Object.fromEntries(Object.entries(domains).map(([key,d])=>[key,d.project()])):{};},
   validate(state){
    // Only the actual in-flight career may finish its staff clock early. An
    // imported/cloned object never matches this private identity guard.
    if(state&&state===nativeStaffTransition?.state&&state.season===nativeStaffTransition.completed+1&&state.staffCareer?.lastAdvancedSeason===nativeStaffTransition.completed-1)domains.staffCareer.advance(state,nativeStaffTransition.completed);
    if(state)for(const d of Object.values(domains))d.validate(state);
   },
   clearTransient(){nativeStaffTransition=null;for(const d of Object.values(domains))if(d.clearTransient)d.clearTransient();},
   execute(command,payload){const owner=owners.get(command);if(!owner)throw Error('Commande de domaine inconnue.');return owner.execute(command,payload);},
   installHooks(){for(const d of Object.values(domains))d.installHooks();}
  };
 })();
 const CDStaffCareer=nativeSystems.domain('staffCareer');
 const CDYouthDevelopment=nativeSystems.domain('youthDevelopment');
 const CDJiff=nativeSystems.domain('jiff');
 // Suivi du centre : le chantier des compétitions de jeunes s'y branche par CDAcademyFollowUp.connect().
 const CDAcademyFollowUp=nativeSystems.domain('academyFollowUp');
 // Championnats actifs : le monde appelle CDLeagueDetail.quickFixture/simulate pour les résultats rapides.
 const CDLeagueDetail=nativeSystems.domain('leagueDetail');
 const CDNativeAcademyGroups=(${academyGroups.toString()})();
 const nativeBaseValidator=validateCareer;
 validateCareer=state=>{const result=nativeBaseValidator(state);nativeSystems.validate(state);if(state)CDNativeAcademyGroups.validate(state);return result;};
 nativeSystems.installHooks();
 CDNativeAcademyGroups.installHooks();
 const staffBaseRoll=rollDevelopmentYear;
 rollDevelopmentYear=function(){
  const before=S?.staffCareer?S.clubs.flatMap(c=>c.players.map(player=>({player,clubId:c.id}))):[];
  const result=staffBaseRoll();
  if(S?.staffCareer){const remaining=new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id)));for(const row of before)if(!remaining.has(row.player.id))CDStaffCareer.captureRetirement(S,row.player,row.clubId);}
  return result;
 };
 const staffBaseAdvance=advanceSeason;
 advanceSeason=function(){const state=S,completed=S?.season;const prior=nativeStaffTransition;nativeStaffTransition={state,completed};try{const result=staffBaseAdvance();if(S===state&&S?.season===completed+1)CDStaffCareer.advance(S,completed);return result;}finally{nativeStaffTransition=prior;}};
 // Capture entrants before their first operation, then measure actual changes.
 // Both observations remain outside import and validation.
 // Preserve existing academy/staff wrappers, their results and hook markers.
 for(const name of ['trainWeek','recordDevelopmentMatch','rollDevelopmentYear','advanceSeason','promoteYouth','managerMobilityOnSeasonStart']){
  const original=globalThis[name];if(typeof original!=='function')continue;
  const observed=function(){if(typeof S!=='undefined'&&S)CDYouthDevelopment.observe(S,name);const result=original.apply(this,arguments);if(typeof S!=='undefined'&&S)CDYouthDevelopment.observe(S,name);return result;};
  Object.assign(observed,original);globalThis[name]=observed;
 }`;
}
module.exports={files,commands,bootstrap};
