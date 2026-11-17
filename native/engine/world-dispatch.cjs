'use strict';

// All career hooks use their own predicate; save validation and projection
// dispatch on the state they were given, including a not-yet-imported state.
module.exports=function worldDispatcher(editions,makeCareer){
 const byEdition=new Map(editions.entries.map(e=>[e,makeCareer(e,s=>editions.forState(s)===e)]));
 const edition=s=>editions.forState(s);
 const current=s=>{
  const result=byEdition.get(edition(s));
  if(!result)throw Error('Édition de carrière mondiale indisponible.');
  return result;
 };
 const onState=name=>(s,...args)=>current(s)[name](s,...args);
 return Object.freeze({
  edition,active:s=>edition(s)!==null,
  start(id,mode='world',dailyCalendar=false){
   const career=byEdition.get(editions.forMode(mode));
   if(!career)throw Error('Édition de carrière mondiale indisponible.');
   return career.start(id,dailyCalendar);
  },
  installHooks(){for(const career of byEdition.values())career.installHooks();},
  sourcePlayerKnown:id=>edition(S)!==null&&current(S).sourcePlayerKnown(id),
  sourcePlayer:(s,id)=>current(s).sourcePlayer(id),
  // Même lecture pour une édition déjà connue (editions.forState(s) lu une fois par l'appelant pour toute une liste).
  sourcePlayerIn:(e,id)=>{const result=byEdition.get(e);if(!result)throw Error('Édition de carrière mondiale indisponible.');return result.sourcePlayer(id);},
  previewRoster:(database,id,full=false)=>byEdition.get(editions.forDatabase(database)).previewRoster(id,full),
  previewFixtures:(mode,dailyCalendar=false)=>byEdition.get(editions.forMode(mode)).previewFixtures(dailyCalendar),
  sizing:onState('sizing'),leagueId:onState('leagueId'),ranked:onState('ranked'),rows:onState('rows'),
  cupTables:onState('cupTables'),fixtures:onState('fixtures'),userFixture:onState('userFixture'),calendarToday:onState('calendarToday'),
  nextOpening:onState('nextOpening'),clubReleaseOn:onState('clubReleaseOn'),
  enableDaily:s=>{if(edition(s))current(s).enableDaily(s);},
  dailyStatus:onState('dailyStatus'),advanceDay:onState('advanceDay'),
  // Météo annoncée la veille du match du club (world-career.cjs) ; null hors carrière Monde.
  ...Object.fromEntries(['fixerMeteo','meteoAnnoncee','meteoMatch','meteoPrevue'].map(name=>[name,(s,...args)=>s&&edition(s)?current(s)[name](s,...args):null])),
  label:onState('label'),validate:onState('validate'),multiplex:onState('multiplex'),finishWeek:()=>current(S).finishWeek(),
 });
};
