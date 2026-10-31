'use strict';
// Modèle fictif de crise : pureté, dette explicite, aucune faillite automatique.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDFinancialRecovery=api})(typeof globalThis==='object'?globalThis:null,function(){
 const ok=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
 function annual(state,{revenue,baseCosts,investment=0,repayment=0}){
  if(!state||!Number.isFinite(state.cash)||!ok(state.debt)||!ok(state.wageRoom)||![revenue,baseCosts,investment,repayment].every(ok))throw RangeError('Budget invalide');
  const opening=state.cash,openingDebt=state.debt;
  const stress=opening<0||openingDebt>Math.max(1,revenue)*.8;
  const restriction=stress?'redressement':opening<revenue*.15?'vigilance':'normal';
  const wageCeiling=restriction==='redressement'?.7:restriction==='vigilance'?.9:1;
  const planned=restriction==='normal'?investment:0;
  const effectiveCosts=restriction==='redressement'?baseCosts*.88:restriction==='vigilance'?baseCosts*.95:baseCosts;
  const available=opening+revenue-effectiveCosts-planned;
  const debtAfterInterest=openingDebt*1.04;
  const paid=Math.min(repayment,debtAfterInterest,Math.max(0,available));
  const closing=available-paid;
  const debt=debtAfterInterest-paid;
  return {cash:closing,debt,restriction,wageCeiling:state.wageRoom*wageCeiling,
   spendingSaved:baseCosts-effectiveCosts,investmentDeferred:investment-planned,
   repayment:paid,net:closing-opening,canRecruit:restriction==='normal'&&closing>0,
   sportingPenalty:restriction==='redressement'?8:restriction==='vigilance'?3:0};
 }
 function recoveryPlan(state,years,flow){
  if(!Number.isInteger(years)||years<1||years>15||typeof flow!=='function')throw RangeError('Plan invalide');
  let current={...state},history=[];
  for(let season=1;season<=years;season++){
   const inputs=flow(season,{...current});
   const next=annual(current,inputs);
   history.push({season,...next});
   current={cash:next.cash,debt:next.debt,wageRoom:current.wageRoom};
  }
  return {history,final:current,firstRecovery:history.find(y=>y.restriction==='normal'&&y.cash>=0)?.season??null};
 }
 return Object.freeze({annual,recoveryPlan});
});
