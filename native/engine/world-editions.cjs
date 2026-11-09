'use strict';

// Kept serialisable so the same marker checks run both outside and inside the
// simulation VM. Existing saves are selected by their exact catalogue and
// version, never by whichever registry is newest.
function createWorldEditions(base,pacific=null){
 const definitions=[
  {mode:'world',id:'rugby-world-2026-11-08-v1',version:1,rules:'world-pro-2026-27-v1',registry:base,clubCount:58,members:{elite:14,accession:16,prem:10,urc:16}},
  ...(pacific?[{mode:'world-pacific',id:'rugby-world-2026-11-09-pacific-v2',version:2,rules:'world-pro-2026-27-srp-2027-v2',registry:pacific,clubCount:68,members:{elite:14,accession:16,prem:10,urc:16,srp:10}}]:[]),
 ];
 const exactMarker=(value,id,version)=>value!==null&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).length===2&&value.id===id&&value.version===version;
 const entries=definitions.map(def=>{
  const {id,version,registry,clubCount,members}=def,leagueIds=Object.keys(members);
  const check=yes=>{if(!yes)throw Error('Configuration d’édition mondiale invalide : '+id);};
  check(registry&&registry.id===id&&registry.version===version&&exactMarker(registry.marker,id,version)&&registry.clubCount===clubCount);
  check(Array.isArray(registry.clubs)&&registry.clubs.length===clubCount&&registry.clubs.every((club,index)=>club?.id===index));
  check(Array.isArray(registry.leagues)&&registry.leagues.length===leagueIds.length+1&&JSON.stringify(registry.leagues.filter(l=>l.id!=='guest').map(l=>l.id))===JSON.stringify(leagueIds));
  const guests=registry.clubs.filter(c=>c.leagueId==='guest').map(c=>c.id);
  check(guests.length===2&&guests[0]===56&&guests[1]===57);
  for(const leagueId of leagueIds)check(registry.clubs.filter(c=>c.leagueId===leagueId).length===members[leagueId]);
  if(version===2)check(registry.clubs.every(c=>c.id>=58?c.leagueId==='srp':c.leagueId===base.clubs[c.id].leagueId));
  return Object.freeze({...def,leagueIds:Object.freeze(leagueIds),members:Object.freeze(members),playable:Object.freeze(registry.clubs.filter(c=>Object.hasOwn(members,c.leagueId)).map(c=>c.id)),guests:Object.freeze(guests)});
 });
 const pick=(key,value)=>entries.find(e=>e[key]===value)||null;
 const forState=s=>{
  const def=pick('id',s?.worldMode?.catalogue);
  return def&&s.worldMode.version===def.version&&exactMarker(s.commonDatabase,def.id,def.version)&&s.franceMode===undefined&&s.lnrMode===undefined?def:null;
 };
 return Object.freeze({entries:Object.freeze(entries),forMode:mode=>pick('mode',mode),forDatabase:id=>pick('id',id),forState});
}
module.exports={createWorldEditions};
