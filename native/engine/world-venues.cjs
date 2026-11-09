'use strict';
const {venues}=require('./epcr-pool-venues-2026-27.json');

// Presentation of the published initial fixtures only. The rules, fixture
// identity and persisted sporting state are independent from a ground label.
module.exports=function publishedWorldVenue(f,careerSeason){
 if(careerSeason!==1||!f)return null;
 if(f.phase==='league'&&['champions','challenge'].includes(f.competitionId)&&f.neutral!==true&&typeof f.id==='string'&&f.id.startsWith(f.competitionId+':')&&Object.hasOwn(venues,f.id)){
  const row=venues[f.id];
  if(row.sourceFixtureId===f.sourceFixtureId&&row.date===f.date&&row.homeId===f.homeId&&row.awayId===f.awayId)return row.venue??'Stade à confirmer';
 }
 if(f.phase!=='final'||f.neutral!==true)return null;
 const date={champions:'2027-05-22',challenge:'2027-05-21'}[f.competitionId];
 return date&&f.date===date?'OL Stadium · Lyon':null;
};
