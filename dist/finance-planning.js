'use strict';
// V41 — outil de simulation financière indépendant du moteur de match.
// Les montants sont fictifs, exprimés dans la même unité que cash et salary.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDFinancePlanning=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const finite=(n)=>typeof n==='number'&&Number.isFinite(n);
 function forecast({cash,weeklyIncome=0,weeklyWages,weeklyOtherCosts=0,oneOffIncome=0,oneOffCosts=0,weeks=12}){
  const amounts=[cash,weeklyIncome,weeklyWages,weeklyOtherCosts,oneOffIncome,oneOffCosts];
  if(!amounts.every(finite)||!Number.isInteger(weeks)||weeks<1||weeks>104)
   throw new RangeError('Paramètres financiers invalides');
  if([weeklyIncome,weeklyWages,weeklyOtherCosts,oneOffIncome,oneOffCosts].some(v=>v<0))
   throw new RangeError('Les coûts et recettes doivent être positifs');
  const weeklyNet=weeklyIncome-weeklyWages-weeklyOtherCosts;
  const entries=[];
  let balance=cash+oneOffIncome-oneOffCosts;
  const initialBalance=balance;
  let firstDeficit=balance<0?0:null;
  for(let week=1;week<=weeks;week++){
   balance+=weeklyNet;
   if(firstDeficit===null&&balance<0)firstDeficit=week;
   entries.push({week,balance,net:weeklyNet});
  }
  return {initialBalance,weeklyNet,finalBalance:balance,firstDeficit,entries,
   salaryShare:weeklyIncome>0?weeklyWages/weeklyIncome:null};
 }
 function compare(base,scenarios){
  if(!Array.isArray(scenarios)||scenarios.length>12)throw new RangeError('Scénarios invalides');
  const baseline=forecast(base);
  return {baseline,scenarios:scenarios.map(s=>{
   if(!s||typeof s.name!=='string'||!s.name.trim()||!s.adjustments||typeof s.adjustments!=='object')
    throw new RangeError('Scénario invalide');
   const permitted=['weeklyIncome','weeklyWages','weeklyOtherCosts','oneOffIncome','oneOffCosts'];
   if(Object.keys(s.adjustments).some(k=>!permitted.includes(k)))throw new RangeError('Ajustement inconnu');
   const result=forecast({...base,...s.adjustments});
   return {name:s.name,result,delta:result.finalBalance-baseline.finalBalance};
  })};
 }
 function stressTest(base,options={}){
  const incomeDrop=options.incomeDrop??0.2;
  const wageRise=options.wageRise??0.1;
  if(!finite(incomeDrop)||incomeDrop<0||incomeDrop>1||!finite(wageRise)||wageRise<0||wageRise>3)
   throw new RangeError('Stress financier invalide');
  const baseline=forecast(base);
  const stressed=forecast({...base,weeklyIncome:(base.weeklyIncome??0)*(1-incomeDrop),
   weeklyWages:base.weeklyWages*(1+wageRise)});
  return {baseline,stressed,loss:baseline.finalBalance-stressed.finalBalance,
   deficitAccelerated:stressed.firstDeficit!==null&&
    (baseline.firstDeficit===null||stressed.firstDeficit<baseline.firstDeficit)};
 }
 function runway(base){
  const projection=forecast({...base,weeks:104});
  const starting=projection.initialBalance;
  const first=projection.firstDeficit;
  const weeklyBalance=projection.weeklyNet;
  const estimated=weeklyBalance<0?Math.floor(starting/(-weeklyBalance))+1:null;
  return {firstDeficitWithin104:first,estimatedWeeksToDeficit:
   starting<0?0:estimated,weeklyNet:weeklyBalance};
 }
 return Object.freeze({forecast,compare,stressTest,runway});
});
