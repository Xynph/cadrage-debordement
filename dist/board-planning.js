'use strict';
// V42 : simulations de gouvernance et de sponsoring fictifs, sans mutation de carrière.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDBoardPlanning=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const valid=n=>typeof n==='number'&&Number.isFinite(n);
 const between=(n,min,max)=>valid(n)&&n>=min&&n<=max;
 function objectiveProgress(objective,actual){
  if(!objective||!['minimum','maximum'].includes(objective.direction)||!valid(objective.target)||!valid(actual))
   throw new RangeError('Objectif invalide');
  const gap=actual-objective.target;
  const met=objective.direction==='minimum'?gap>=0:gap<=0;
  return {met,gap,remaining:met?0:Math.abs(gap)};
 }
 function boardConfidence({current,results,finances,youth,weights={results:.55,finances:.3,youth:.15}}){
  if(!between(current,0,100)||![results,finances,youth].every(n=>between(n,0,100))||
   !weights||Object.values(weights).some(n=>!between(n,0,1))||
   !['results','finances','youth'].every(k=>valid(weights[k]))||
   Math.abs(weights.results+weights.finances+weights.youth-1)>1e-8)
   throw new RangeError('Évaluation du conseil invalide');
  const score=results*weights.results+finances*weights.finances+youth*weights.youth;
  const next=Math.max(0,Math.min(100,Math.round(current*.7+score*.3)));
  return {next,change:next-current,score,warning:next<35};
 }
 function sponsorContract({weeklyPayment=0,signingBonus=0,winBonus=0,rankingBonus=0,weeks,wins=0,rankingReached=false}){
  if(![weeklyPayment,signingBonus,winBonus,rankingBonus,wins].every(n=>valid(n)&&n>=0)||
    !Number.isInteger(weeks)||weeks<1||weeks>104||!Number.isInteger(wins)||wins>weeks||
    typeof rankingReached!=='boolean')
   throw new RangeError('Contrat de sponsoring invalide');
  const guaranteed=weeklyPayment*weeks+signingBonus;
  const performance=winBonus*wins+(rankingReached?rankingBonus:0);
  return {guaranteed,performance,total:guaranteed+performance,weeklyEquivalent:(guaranteed+performance)/weeks};
 }
 return Object.freeze({objectiveProgress,boardConfidence,sponsorContract});
});
