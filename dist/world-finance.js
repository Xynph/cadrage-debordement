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
  for(let season=1;season<=seasons;season++){
   // Une seule saison à la fois : le moteur sportif existant garde sa propre logique.
   // Le compte économique est calculé séparément, sans double comptage de ses recettes fictives.
   const sporting=world.simulate({clubs:state.map(c=>({...c,cash:Math.max(0,c.cash)})),seasons:1,seed:(seed+season*2654435761)>>>0,adapters});
   const ranking=sporting.history[0].standings;
   const rows=[];
   for(const row of ranking){
    const club=state.find(c=>c.id===row.clubId);
    const profile=profiles[club.id]||{};
    const revenue=profile.revenue??(90000+row.reputation*1200+(state.length-row.finish)*4000);
    const baseCosts=profile.baseCosts??(125000+row.facilities*3500);
    const investment=profile.investment??(row.facilities<10?60000+row.facilities*12000:0);
    const repayment=profile.repayment??15000;
    const result=finance.annual(club,{revenue,baseCosts,investment,repayment});
    club.cash=result.cash;club.debt=result.debt;
    club.reputation=row.reputation;club.facilities=row.facilities;
    club.coachConfidence=sporting.clubs.find(c=>c.id===club.id).coachConfidence;
    const blocked=result.restriction!=='normal';
    if(blocked)events.push({season,clubId:club.id,type:'financialRestriction',level:result.restriction});
    rows.push({...row,cash:club.cash,debt:club.debt,restriction:result.restriction,spendingSaved:result.spendingSaved,
     investmentDeferred:result.investmentDeferred,canRecruit:result.canRecruit,sportingPenalty:result.sportingPenalty});
   }
   events.push(...sporting.events.map(e=>({...e,season})));
   history.push({season,champion:sporting.history[0].champion,standings:rows,awards:sporting.history[0].awards});
  }
  return {seed,seasons,clubs:state,history,events};
 }
 return Object.freeze({simulate});
});
