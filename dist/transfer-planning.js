'use strict';
// V44 : analyse de recrutement sans signature, transfert ou écriture de sauvegarde.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDTransferPlanning=api})(typeof globalThis==='object'?globalThis:null,function(){
 const valid=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
 function transferCost({fee=0,weeklyWage,signingBonus=0,agentFee=0,weeks}){
  if(![fee,weeklyWage,signingBonus,agentFee].every(valid)||!Number.isInteger(weeks)||weeks<1||weeks>520)
   throw new RangeError('Coût contractuel invalide');
  const upFront=fee+signingBonus+agentFee,recurring=weeklyWage*weeks;
  return {upFront,recurring,total:upFront+recurring,averageWeekly:(upFront+recurring)/weeks};
 }
 function affordability({cash,transferBudget,wageRoom,fee=0,weeklyWage,signingBonus=0,agentFee=0,weeks}){
  if(![cash,transferBudget,wageRoom].every(valid))throw new RangeError('Budget invalide');
  const cost=transferCost({fee,weeklyWage,signingBonus,agentFee,weeks});
  return {...cost,upFrontAffordable:cost.upFront<=cash&&cost.upFront<=transferBudget,
   wageAffordable:weeklyWage<=wageRoom,
   affordable:cost.upFront<=cash&&cost.upFront<=transferBudget&&weeklyWage<=wageRoom,
   cashAfter:cash-cost.upFront,transferBudgetAfter:transferBudget-cost.upFront,
   wageRoomAfter:wageRoom-weeklyWage};
 }
 function rankCandidates(candidates,{weeks=104,feeWeight=.3,qualityWeight=.7}={}){
  if(!Array.isArray(candidates)||!Number.isInteger(weeks)||weeks<1||weeks>520||
   !valid(feeWeight)||!valid(qualityWeight)||Math.abs(feeWeight+qualityWeight-1)>1e-8)
   throw new RangeError('Classement invalide');
  const ids=new Set();
  const results=candidates.map(p=>{
   if(!p||typeof p.id!=='string'||!p.id||ids.has(p.id)||
    typeof p.pos!=='string'||!p.pos||!valid(p.quality)||p.quality>100)
    throw new RangeError('Candidat invalide');
   ids.add(p.id);
   const cost=transferCost({...p,weeks});
   const value=qualityWeight*p.quality-feeWeight*(cost.total/100000);
   return {id:p.id,pos:p.pos,quality:p.quality,totalCost:cost.total,value};
  });
  return results.sort((a,b)=>b.value-a.value||a.totalCost-b.totalCost||a.id.localeCompare(b.id));
 }
 return Object.freeze({transferCost,affordability,rankCandidates});
});
