'use strict';
// Pont indépendant V51 : simulations sportives annuelles et finances signées.
(function(root,factory){const api=factory(
 typeof module==='object'&&module.exports?require('./world-simulation.js'):root.CDWorldSimulation,
 typeof module==='object'&&module.exports?require('./financial-recovery.js'):root.CDFinancialRecovery
 );if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDWorldFinance=api})(typeof globalThis==='object'?globalThis:null,function(world,finance){
 function simulate({clubs,seasons=15,seed=1,adapters,profiles={},checkpoint=null}){
  if(!world||!finance||!Array.isArray(clubs)||!Number.isInteger(seasons)||seasons<1||seasons>15||
    !Number.isInteger(seed)||seed<0||seed>4294967295)throw RangeError('Paramètres invalides');
  if(clubs.some(c=>!c||typeof c.id!=='string'||typeof c.cash!=='number'||!Number.isFinite(c.cash)||
     !Number.isFinite(c.debt??0)||(c.debt??0)<0||!Number.isFinite(c.wageRoom)||c.wageRoom<0))
   throw RangeError('Club invalide');
  if(checkpoint!==null){
   if(!checkpoint||checkpoint.version!==1||checkpoint.seed!==seed||!Number.isInteger(checkpoint.completed)||checkpoint.completed<1||checkpoint.completed>=15||
      checkpoint.completed>=seasons||!Array.isArray(checkpoint.clubs)||!Array.isArray(checkpoint.history)||!Array.isArray(checkpoint.events)||
      checkpoint.history.length!==checkpoint.completed||checkpoint.clubs.length!==clubs.length)throw RangeError('Checkpoint invalide');
   const ids=new Set(clubs.map(c=>c.id));
   if(ids.size!==clubs.length||checkpoint.clubs.some(c=>!c||!ids.has(c.id)||!Number.isFinite(c.cash)||!Number.isFinite(c.debt)||c.debt<0||
      !Number.isFinite(c.reputation)||c.reputation<0||c.reputation>100||!Number.isInteger(c.facilities)||c.facilities<1||c.facilities>10||
      !Number.isFinite(c.coachConfidence)||c.coachConfidence<0||c.coachConfidence>100))throw RangeError('Checkpoint clubs invalide');
   if(!checkpoint.penalties||typeof checkpoint.penalties!=='object'||Array.isArray(checkpoint.penalties)||
    Object.keys(checkpoint.penalties).length!==ids.size||Object.keys(checkpoint.penalties).some(id=>!ids.has(id)))throw RangeError('Malus checkpoint invalides');
   if(new Set(checkpoint.clubs.map(c=>c.id)).size!==ids.size)throw RangeError('Doublon checkpoint');
   if(checkpoint.history.some((h,i)=>!h||h.season!==i+1||!Array.isArray(h.standings)||h.standings.length!==clubs.length||
      !Array.isArray(h.awards)||typeof h.champion!=='string'||!ids.has(h.champion)||
      new Set(h.standings.map(r=>r.clubId)).size!==ids.size||
      new Set(h.standings.map(r=>r.finish)).size!==ids.size||
      h.standings.some(r=>!r||!ids.has(r.clubId)||!Number.isInteger(r.finish)||r.finish<1||r.finish>ids.size||
        !Number.isFinite(r.cash)||!Number.isFinite(r.debt)||r.debt<0||!Number.isFinite(r.reputation)||r.reputation<0||r.reputation>100||
        !Number.isInteger(r.facilities)||r.facilities<1||r.facilities>10)||
      h.standings.find(r=>r.finish===1)?.clubId!==h.champion))throw RangeError('Historique checkpoint invalide');
   if(checkpoint.events.some(e=>!e||!ids.has(e.clubId)||!Number.isInteger(e.season)||e.season<1||e.season>checkpoint.completed||
      typeof e.type!=='string'))throw RangeError('Événement checkpoint invalide');
   const final=new Map(checkpoint.history.at(-1).standings.map(r=>[r.clubId,r]));
   if(checkpoint.clubs.some(c=>{const r=final.get(c.id);return !r||r.cash!==c.cash||r.debt!==c.debt||r.reputation!==c.reputation||r.facilities!==c.facilities;}))
      throw RangeError('État final incompatible avec historique');
  }
  const state=(checkpoint?checkpoint.clubs:clubs).map(c=>({...c,debt:c.debt??0}));
  const history=checkpoint?checkpoint.history.map(h=>({...h,standings:h.standings.map(r=>({...r})),awards:h.awards.map(a=>({...a}))})):[];
  const events=checkpoint?checkpoint.events.map(e=>({...e})):[];
  let penalties=checkpoint?Object.fromEntries(state.map(c=>[c.id,checkpoint.penalties[c.id]])):Object.fromEntries(state.map(c=>[c.id,c.cash<0||c.debt>0?8:0]));
  if(Object.values(penalties).some(p=>!Number.isFinite(p)||p<0||p>100))throw RangeError('Malus checkpoint invalide');
  for(let season=(checkpoint?.completed??0)+1;season<=seasons;season++){
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
    rows.push({...row,cash:club.cash,debt:club.debt,facilities:club.facilities,restriction:result.restriction,spendingSaved:result.spendingSaved,
     investmentDeferred:result.investmentDeferred,investmentPaid:invested,canRecruit:result.canRecruit,sportingPenalty:result.sportingPenalty});
   }
   penalties=nextPenalties;
   events.push(...sporting.events.map(e=>({...e,season})));
   history.push({season,champion:sporting.history[0].champion,standings:rows,awards:sporting.history[0].awards});
  }
  return {seed,seasons,clubs:state,history,events,checkpoint:{version:1,seed,completed:seasons,clubs:state.map(c=>({...c})),history:history.map(h=>({...h,standings:h.standings.map(r=>({...r})),awards:h.awards.map(a=>({...a}))})),events:events.map(e=>({...e})),penalties:{...penalties}}};
 }
 return Object.freeze({simulate});
});
