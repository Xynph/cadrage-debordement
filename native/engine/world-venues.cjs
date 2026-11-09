'use strict';
const {venues:epcr}=require('./epcr-pool-venues-2026-27.json');
const {venues:srp}=require('./srp-venues-2027.json');
const {venues:jlo}=require('./jlo-venues-2026-27.json');
const {venues:premUrc}=require('./prem-urc-venues-2026-27.json');
const data={epcr,domestic:{...srp,...jlo,...premUrc}};

// Factory source is also evaluated in the isolated simulation VM. Ground
// records are supplied once at creation rather than captured by a host closure.
function factory({epcr,domestic}){
 return function publishedWorldVenue(f,careerSeason){
  if(careerSeason!==1||!f)return null;
  if(f.phase==='league'&&typeof f.id==='string'&&Object.hasOwn(domestic,f.id)){
   const row=domestic[f.id];
   if(row.competitionId===f.competitionId&&row.date===f.date&&row.homeId===f.homeId&&row.awayId===f.awayId&&row.neutral===f.neutral&&(row.sourceFixtureId===undefined||row.sourceFixtureId===f.sourceFixtureId))
    return row.venue??'Stade à confirmer';
  }
  if((f.phase==='pool'||f.phase==='league')&&['champions','challenge'].includes(f.competitionId)&&f.neutral!==true&&typeof f.id==='string'&&f.id.startsWith(f.competitionId+':')&&Object.hasOwn(epcr,f.id)){
   const row=epcr[f.id];
   if(row.sourceFixtureId===f.sourceFixtureId&&row.date===f.date&&row.homeId===f.homeId&&row.awayId===f.awayId)return row.venue??'Stade à confirmer';
  }
  if(f.phase!=='final'||f.neutral!==true)return null;
  const date={champions:'2027-05-22',challenge:'2027-05-21'}[f.competitionId];
  return date&&f.date===date?'OL Stadium · Lyon':null;
 };
}
module.exports=factory(data);
module.exports.factory=factory;
module.exports.data=data;
