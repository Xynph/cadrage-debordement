'use strict';
// Competition presentation only. The calendar and sporting state already
// contain the neutral finals dates; this does not turn later draws into facts.
module.exports=function publishedWorldVenue(f,careerSeason){
 if(careerSeason!==1||f?.phase!=='final'||f.neutral!==true)return null;
 const date={champions:'2027-05-22',challenge:'2027-05-21'}[f.competitionId];
 return date&&f.date===date?'OL Stadium · Lyon':null;
};
