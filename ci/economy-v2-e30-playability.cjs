'use strict';
// E3.0 R&D only: a pure decision sandbox. No import into game and no accounting postings.
const check=(v,msg)=>{if(!v)throw Error(msg)};
const amount=v=>Number.isSafeInteger(v)&&v>=0&&v<=1e12;
const signed=v=>Number.isSafeInteger(v)&&Math.abs(v)<=1e12;
const modes=Object.freeze({
 maintain:{id:'maintain',label:'Maintenir le projet sportif',tradeoff:'Priorités sportives intactes ; tension de trésorerie possible'},
 stage:{id:'stage',label:'Échelonner les projets facultatifs',tradeoff:'Développement plus lent ; aucun achat non exigible imposé'},
 pause:{id:'pause',label:'Suspendre les achats facultatifs',tradeoff:'Liquidités préservées ; projets sportifs reportés ou annulés'}
});
function normalize(input){
 check(input&&typeof input==='object'&&signed(input.openingCash),'Trésorerie initiale invalide');
 const {income,required,optional}=input;
 check(Array.isArray(income)&&income.length>0&&income.length<=58&&Array.isArray(required)&&required.length===income.length&&Array.isArray(optional)&&optional.length===income.length,'Calendrier invalide');
 check([...income,...required,...optional].every(amount),'Flux négatif, imprécis ou absent');
 const reserve=input.targetReserve===undefined?0:input.targetReserve;
 check(amount(reserve),'Réserve volontaire invalide');
 check(!Object.hasOwn(input,'automaticLoan')&&!Object.hasOwn(input,'unverifiedIncome'),'Aucun prêt ni revenu créé implicitement');
 return {openingCash:input.openingCash,income:[...income],required:[...required],optional:[...optional],targetReserve:reserve};
}
function simulate(input,mode){
 const v=normalize(input);check(Object.hasOwn(modes,mode),'Option inconnue');
 let cash=v.openingCash,minCash=cash,negativeWeeks=0,firstDeficit=null,firstReturn=null;
 let pending=0,optionalPaid=0,optionalDeferred=0,coverageFails=0;
 const weeks=[];
 for(let i=0;i<v.income.length;i++){
  const before=cash,available=before+v.income[i]-v.required[i];
  if(available<0)coverageFails++;
  let invest=0;
  if(mode==='maintain')invest=v.optional[i];
  if(mode==='stage'){
   // Optional plans can be moved to a later week but not booked as legally due.
   pending+=v.optional[i];
   // Reserve sufficient cash for the WORST mandatory-only position through the horizon,\n   // never merely this week's balance (which can hide upcoming payroll bills).\n   let mandatoryWorst=available,projected=available;\n   for(let j=i+1;j<v.income.length;j++){projected+=v.income[j]-v.required[j];mandatoryWorst=Math.min(mandatoryWorst,projected)}\n   invest=Math.min(pending,Math.max(0,mandatoryWorst-v.targetReserve));
   pending-=invest;
  }
  if(mode==='pause')pending+=v.optional[i];
  if(mode==='maintain')pending=0;
  cash=available-invest;
  check(Number.isSafeInteger(cash)&&Math.abs(cash)<=1e14,'Projection hors plage');
  optionalPaid+=invest;
  if(cash<0){negativeWeeks++;if(firstDeficit===null)firstDeficit=i+1}
  if(firstDeficit!==null&&firstReturn===null&&cash>=0)firstReturn=i+1;
  minCash=Math.min(minCash,cash);
  weeks.push({week:i+1,openingCash:before,received:v.income[i],mandatoryPaid:v.required[i],
   optionalPaid:invest,closingCash:cash,optionalQueue:pending});
 }
 optionalDeferred=pending;
 return {mode,headline:modes[mode].label,tradeoff:modes[mode].tradeoff,
  openingCash:v.openingCash,endingCash:cash,minimumCash:minCash,negativeWeeks,
  firstDeficitWeek:firstDeficit,firstRecoveryWeek:firstReturn,requiredCoverageRiskWeeks:coverageFails,
  optionalPlanned:v.optional.reduce((a,b)=>a+b,0),optionalPaid,optionalDeferred,
  generatedIncome:0,generatedLoans:0,createdDebt:0,addedPenalties:0,
  targetReserve:v.targetReserve,forecastOnly:true,weekly:weeks};
}
function compare(input){
 const options=Object.keys(modes).map(mode=>simulate(input,mode));
 const maintain=options[0],stage=options[1],pause=options[2];
 const recoveryPossible=options.some(x=>x.endingCash>=0&&x.negativeWeeks===0);
 const mandatoryUnfunded=options.some(x=>x.requiredCoverageRiskWeeks>0);
 return {schema:1,options,summary:{
  recoveryPossibleWithoutNewMoney:recoveryPossible,
  optionalChangesInsufficientForMandatoryBills:mandatoryUnfunded,
  voluntaryChoiceAvailable:input.optional.some(x=>x>0),
  bestEndingCash:Math.max(...options.map(x=>x.endingCash)),
  protectedCashVsMaintain:pause.endingCash-maintain.endingCash,
  stagedCashVsMaintain:stage.endingCash-maintain.endingCash,
  note:mandatoryUnfunded?'Économies facultatives insuffisantes pour couvrir certaines échéances : négocier volontairement une aide réelle, sans créer de prêt implicite.':'Le joueur peut arbitrer le rythme des projets sans pénalité ajoutée.'}};
}
module.exports=Object.freeze({normalize,simulate,compare,MODES:modes});
