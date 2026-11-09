'use strict';
const {venues}=require('./epcr-pool-venues-2026-27.json');

// Factory source is also evaluated in the isolated simulation VM. Ground
// records are supplied once at creation rather than captured by a host closure.
function factory(rows){
 return function publishedWorldVenue(f,careerSeason){
  if(careerSeason!==1||!f)return null;
  if((f.phase==='pool'||f.phase==='league')&&['champions','challenge'].includes(f.competitionId)&&f.neutral!==true&&typeof f.id==='string'&&f.id.startsWith(f.competitionId+':')&&Object.hasOwn(rows,f.id)){
   const row=rows[f.id];
   if(row.sourceFixtureId===f.sourceFixtureId&&row.date===f.date&&row.homeId===f.homeId&&row.awayId===f.awayId)return row.venue??'Stade à confirmer';
  }
  if(f.phase!=='final'||f.neutral!==true)return null;
  const date={champions:'2027-05-22',challenge:'2027-05-21'}[f.competitionId];
  return date&&f.date===date?'OL Stadium · Lyon':null;
 };
}
module.exports=factory(venues);
module.exports.factory=factory;
module.exports.data=venues;
