'use strict';
// Pont indépendant V51 : simulations sportives annuelles et finances signées.
(function(root,factory){const api=factory(
 typeof module==='object'&&module.exports?require('./world-simulation.js'):root.CDWorldSimulation,
 typeof module==='object'&&module.exports?require('./financial-recovery.js'):root.CDFinancialRecovery
 );if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDWorldFinance=api})(typeof globalThis==='object'?globalThis:null,function(world,finance){
 function simulate({clubs,seasons=15,seed=1,adapters,profiles={}}){
  if(!world||!finance||!Array.isArray(clubs)||!Number.isInteger(seasons)||seasons<1||seasons>15||
    !Number.isInteger(seed)||seed<0||seed>4294967295)throw RangeError('Paramètres invalides');
  if(clubs.some(c=>!c||typeof c.id!=='string'||typeof c.cash!=='number'||!Number.isFinite(c.cash)||
     !Number.isFinite(c.debt??0)||(c.debt??0)<0||!Number.isFinite(c.wageRoom)||c.wageRoom<0))
   throw RangeError('Club invalide');
  const state=clubs.map(c=>({...c,debt:c.debt??0}));
  const history=[],events=[];
  let penalties=Object.fromEntries(state.map(c=>[c.id,c.cash<0||c.debt>0?8:0]));
  for(let season=1;season<=seasons;season++){
   // Une seule saison à la fois : le moteur sportif existant garde sa propre logique.
   // Le compte économique est calculé séparément, sans double comptage de ses recettes fictives.
   const sporting=world.simulate({clubs:state.map(c=>({...c,cash:Math.max(0,c.cash)})),seasons:1,seed:(seed+season*2654435761)>>>0,adapters,externalEconomy:true,sportingPenalties:penalties});
   const ranking=sporting.history[0].standings;
   const rows=[];
   const nextPenalties={};
   for(const row of ranking){
    const club=state.find(c=>c.id===row.clubId);
    const profile=profiles[club.id]||{};
    const revenue=profile.revenue??(90000+row.reputation*1200+(state.length-row.finish)*4000);
    const baseCosts=profile.baseCosts??(125000+row.facilities*3500);
    const investment=profile.investment??(row.facilities<10?60000+row.facilities*12000:0);
    const repayment=profile.repayment??15000;
    if(![revenue,baseCosts,investment,repayment].every(n=>typeof n==='number'&&Number.isFinite(n)&&n>=0))throw RangeError('Profil financier invalide');
    const quote=adapters.facility({cash:Math.max(0,club.cash),level:club.facilities,cost:investment,weeks:1});
    const stressed=club.cash<0||club.debt>Math.max(1,revenue)*.8;
    const planned=stressed?investment:(club.cash>=investment&&club.cash+revenue-baseCosts-investment>=0&&club.facilities<10&&quote?.affordable===true?investment:0);
    const result=finance.annual(club,{revenue,baseCosts,investment:planned,repayment});
    club.cash=result.cash;club.debt=result.debt;
    club.reputation=row.reputation;
    const priorFacility=club.facilities;
    const invested=result.restriction==='normal'&&planned>0&&result.investmentDeferred===0?planned:0;
    if(invested>0){club.facilities=Math.min(10,priorFacility+1);events.push({season,clubId:club.id,type:'facility',cost:invested});}
    
    nextPenalties[club.id]=result.sportingPenalty;
    club.coachConfidence=sporting.clubs.find(c=>c.id===club.id).coachConfidence;
    const blocked=result.restriction!=='normal';
    if(blocked)events.push({season,clubId:club.id,type:'financialRestriction',level:result.restriction});
    rows.push({...row,cash:club.cash,debt:club.debt,restriction:result.restriction,spendingSaved:result.spendingSaved,
     investmentDeferred:result.investmentDeferred,investmentPaid:invested,canRecruit:result.canRecruit,sportingPenalty:result.sportingPenalty});
   }
   penalties=nextPenalties;
   events.push(...sporting.events.map(e=>({...e,season})));
   history.push({season,champion:sporting.history[0].champion,standings:rows,awards:sporting.history[0].awards});
  }
  return {seed,seasons,clubs:state,history,events};
 }
 return Object.freeze({simulate});
});
