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
 return Object.freeze({forecast,compare});
});
