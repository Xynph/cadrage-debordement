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
  previewRoster:(database,id)=>byEdition.get(editions.forDatabase(database)).previewRoster(id),
  sizing:onState('sizing'),leagueId:onState('leagueId'),ranked:onState('ranked'),rows:onState('rows'),
  cupTables:onState('cupTables'),fixtures:onState('fixtures'),userFixture:onState('userFixture'),calendarToday:onState('calendarToday'),
  enableDaily:s=>{if(edition(s))current(s).enableDaily(s);},
  dailyStatus:onState('dailyStatus'),advanceDay:onState('advanceDay'),
  label:onState('label'),validate:onState('validate'),finishWeek:()=>current(S).finishWeek(),
 });
};
