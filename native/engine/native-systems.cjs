'use strict';
const academyGroups=require('./academy-groups.cjs'),matchNotes=require('./match-notes.cjs');
// Feuille de statistiques réaliste (match-stats.cjs) : la même que l'écran de match, enregistrée par les notes.
const matchStats=require('./match-stats.cjs');
// Closed production manifest. Each domain owns its rules and strict validator;
// the worker remains the only disk transaction and save authority.
const domains={clubMeetings:require('./club-meetings.cjs'),matchTalks:require('./match-talks.cjs'),matchDelegation:require('./match-delegation.cjs'),sceneInvitations:require('./scene-invitations.cjs'),playerMatchHistory:require('./player-match-history.cjs'),staffEmployment:require('./staff-employment.cjs'),customCompetition:require('./custom-competition.cjs'),interclubMarket:require('./interclub-market.cjs'),staffMentoring:require('./staff-mentoring.cjs'),performanceAnalysis:require('./performance-analysis.cjs'),press:require('./press.cjs'),relationships:require('./relationships.cjs'),clubWorld:require('./club-world.cjs'),academyPathways:require('./academy.cjs'),clubStrategy:require('./club-strategy.cjs'),clubSupport:require('./club-support.cjs'),managerCareer:require('./manager-career.cjs'),playbook:require('./playbook.cjs'),coachNotebook:require('./coach-notes.cjs'),staffCareer:require('./staff-career.cjs'),regenScouting:require('./regen-scouting.cjs'),youthDevelopment:require('./youth-development.cjs'),academyIntake:require('./academy-intake.cjs'),jiff:require('./jiff.cjs'),youthNational:require('./youth-national.cjs'),formationFees:require('./formation-fees.cjs'),academyFollowUp:require('./academy-follow-up.cjs'),youthMatches:require('./youth-matches.cjs'),matchNotes,espoirsMatch:require('./espoirs-match.cjs'),preseason:require('./avant-saison.cjs'),reprise:require('./reprise.cjs'),leagueDetail:require('./league-detail.cjs')};
const files=Object.freeze([...new Set(Object.values(domains).flatMap(d=>d.files))]);
const commands=Object.freeze(Object.values(domains).flatMap(d=>d.commands));
if(new Set(commands).size!==commands.length)throw Error('Commandes natives de domaine en double.');
function bootstrap(){
 const definitions=Object.entries(domains).map(([key,d])=>JSON.stringify(key)+':('+d.factory.toString()+')()').join(',');
 return `const nativeStaffCareerSources=(()=>{const freeze=value=>{if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;};return freeze(typeof nativeStaffCareerSourcesText==='string'?JSON.parse(nativeStaffCareerSourcesText):{});})();
 let nativeStaffTransition=null;
 const CDMatchNotesMoteur=(${matchNotes.moteur.toString()})();
 const CDMatchStats=(${matchStats.fabrique.toString()})();
 const nativeSystems=(()=>{
  const domains={${definitions}},owners=new Map(),memo=new Map(),memoStats={};
  // Domaines mémorisables : projections coûteuses relues sans changement entre deux décisions (marché entre clubs,
  // carrière du manager, staff…), sans état transitoire ni dépendance au déroulé d'une commande.
  const MEMO_DOMAINS=new Set(['interclubMarket','managerCareer','regenScouting','clubSupport','staffCareer','coachNotebook','youthDevelopment','staffMentoring','clubWorld','performanceAnalysis','staffEmployment']);
  ${Object.entries(domains).map(([key,d])=>d.commands.map(c=>`owners.set(${JSON.stringify(c)},domains[${JSON.stringify(key)}]);`).join('')).join('')}
  return {
   domain(id){return domains[id]||null;},
   project(){return S?Object.fromEntries(Object.entries(domains).map(([key,d])=>[key,d.project()])):{};},
   // Texte JSON de project(), identique caractère pour caractère, avec mémoire par domaine : un domaine de MEMO_DOMAINS
   // (projection lourde, sans état transitoire) dont les sections de premier niveau de S lues lors du dernier calcul ont
   // exactement le même texte qu'alors reprend son texte précédent au lieu d'être recalculé. Les sections lues sont
   // relevées par un mandataire posé sur S le temps du calcul ; une énumération des clés de S rend le domaine
   // dépendant de tout l'état. CD_MEMO_DOMAINES=0 coupe la mémoire ; CD_VERIFIER_MEMO=1 recalcule et compare.
   projectText(sections){
    if(!S)return '{}';
    if(!sections||nativeMemoDomains===false){memo.clear();return JSON.stringify(this.project());}
    return '{'+this.projectParts(sections).map(([key,text])=>JSON.stringify(key)+':'+text).join(',')+'}';
   },
   // Même calcul que projectText, domaine par domaine : [clé, texte] dans l'ordre des domaines (texte repris de la
   // mémoire = même chaîne qu'au calcul précédent). « skip » (Set de clés de MEMO_DOMAINS, direct du match) : ces
   // domaines ne sont ni calculés ni repris ; leur texte vaut null et l'appelant garde leur dernière présentation.
   projectParts(sections,skip=null){
    if(!S)return [];
    const parts=[];
    for(const [key,d] of Object.entries(domains)){
     let text;
     if(skip&&skip.has(key)&&MEMO_DOMAINS.has(key)){parts.push([key,null]);continue;}
     if(!MEMO_DOMAINS.has(key)){text=JSON.stringify(d.project());}
     else{
      const hit=memo.get(key);
      const stale=hit?hit.all?['*']:hit.deps.filter(([k,t])=>sections.get(k)!==t).map(([k])=>k):null;
      memoStats[key]=stale===null?'calcul':stale.length?'périmé:'+stale.join('+'):'repris';
      if(hit&&stale.length===0){
       text=hit.text;
       if(nativeVerifyMemo){const fresh=JSON.stringify(d.project());if(fresh!==text)throw Error('Mémoire de projection périmée : '+key+'.');}
      }else{
       const real=S,read=new Set();let all=false;
       const traced=new Proxy(real,{get(t,k,r){if(typeof k==='string')read.add(k);return Reflect.get(t,k,t);},has(t,k){if(typeof k==='string')read.add(k);return Reflect.has(t,k);},ownKeys(t){all=true;return Reflect.ownKeys(t);},getOwnPropertyDescriptor(t,k){if(typeof k==='string')read.add(k);return Reflect.getOwnPropertyDescriptor(t,k);}});
       S=traced;
       try{text=JSON.stringify(d.project());}finally{S=real;}
       memo.set(key,{text,all,deps:[...read].map(k=>[k,sections.get(k)])});
      }
     }
     if(text!==undefined)parts.push([key,text]);
    }
    return parts;
   },
   memoDomains(){return [...MEMO_DOMAINS];},
   clearMemo(){memo.clear();},
   memoStats(){return {...memoStats};},
   validate(state){
    // Only the actual in-flight career may finish its staff clock early. An
    // imported/cloned object never matches this private identity guard.
    if(state&&state===nativeStaffTransition?.state&&state.season===nativeStaffTransition.completed+1&&state.staffCareer?.lastAdvancedSeason===nativeStaffTransition.completed-1)domains.staffCareer.advance(state,nativeStaffTransition.completed);
    if(state)for(const d of Object.values(domains))d.validate(state);
   },
   // keepMemo : carrière rétablie à l'identique (commande refusée) ; la mémoire, indexée par les versions des sections
   // lues, reste juste.
   clearTransient(keepMemo){if(!keepMemo)memo.clear();nativeStaffTransition=null;for(const d of Object.values(domains))if(d.clearTransient)d.clearTransient();},
   execute(command,payload){const owner=owners.get(command);if(!owner)throw Error('Commande de domaine inconnue.');return owner.execute(command,payload);},
   installHooks(){for(const d of Object.values(domains))d.installHooks();}
  };
 })();
 const CDStaffCareer=nativeSystems.domain('staffCareer');
 const CDMatchNotes=nativeSystems.domain('matchNotes');
 const CDYouthDevelopment=nativeSystems.domain('youthDevelopment');
 const CDJiff=nativeSystems.domain('jiff');
 const CDYouthNational=nativeSystems.domain('youthNational');
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
// Extend the closed registry after its definitions, away from the shared domain list.
domains.managerPlanning=require('./manager-planning.cjs');
// Fiche d'un club (XV type, effectif, clubs suivis) : native/engine/club-sheet.cjs.
domains.clubSheet=require('./club-sheet.cjs');
// Promesses publiques en conférence de presse (native/engine/press-promises.cjs), servies par le domaine press.
domains.pressPromises=require('./press-promises.cjs');
const allFiles=Object.freeze([...new Set([...files,...domains.managerPlanning.files,...domains.clubSheet.files,...domains.pressPromises.files])]);
const allCommands=Object.freeze([...commands,...domains.managerPlanning.commands,...domains.clubSheet.commands,...domains.pressPromises.commands]);
if(new Set(allCommands).size!==allCommands.length)throw Error('Commandes natives de domaine en double.');
module.exports={files:allFiles,commands:allCommands,bootstrap};
