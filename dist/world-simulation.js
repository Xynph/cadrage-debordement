'use strict';
// V51 : moteur pluriannuel pur. Les adaptateurs V46–V50 sont injectés par l'appelant.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDWorldSimulation=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const valid=n=>typeof n==='number'&&Number.isFinite(n);
 function rng(seed){
  if(!Number.isInteger(seed)||seed<0||seed>4294967295)throw new RangeError('Graine invalide');
  let state=seed>>>0;
  return ()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
 }
 function validateClubs(clubs){
  if(!Array.isArray(clubs)||clubs.length<2||clubs.length>30)throw new RangeError('Clubs invalides');
  const ids=new Set();
  for(const c of clubs){
   if(!c||typeof c.id!=='string'||!c.id||ids.has(c.id)||
      !valid(c.cash)||c.cash<0||!valid(c.reputation)||c.reputation<0||c.reputation>100||
      !valid(c.wageRoom)||c.wageRoom<0||!Number.isInteger(c.facilities)||c.facilities<1||c.facilities>10||
      !valid(c.coachConfidence)||c.coachConfidence<0||c.coachConfidence>100)
    throw new RangeError('Club invalide');
   ids.add(c.id);
  }
 }
 function simulate({clubs,seasons=10,seed=1,adapters,externalEconomy=false,sportingPenalties={}}){
  if(typeof externalEconomy!=='boolean'||!sportingPenalties||typeof sportingPenalties!=='object'||Array.isArray(sportingPenalties))throw RangeError('Options invalides');
  validateClubs(clubs);
  if(!Number.isInteger(seasons)||seasons<1||seasons>15)throw new RangeError('Durée invalide');
  if(!adapters||!['reputation','coachRisk','facility','recruitment','world'].every(k=>typeof adapters[k]==='function'))
   throw new TypeError('Adaptateurs V46–V50 manquants');
  const random=rng(seed);
  const state=clubs.map(c=>({...c}));
  const history=[],events=[];
  for(let season=1;season<=seasons;season++){
   const ordered=state.map(c=>({id:c.id,form:c.reputation+random()*24+(c.facilities-5)*2-(sportingPenalties[c.id]??0)}))
     .sort((a,b)=>b.form-a.form||a.id.localeCompare(b.id));
   const ranks=new Map(ordered.map((v,i)=>[v.id,i+1]));
   const seasonRows=[];
   for(const c of state){
    const finish=ranks.get(c.id);
    
    const reputation=adapters.reputation({current:c.reputation,leagueFinish:finish,leagueSize:state.length,champion:finish===1,financeHealthy:c.cash>0});
    if(!reputation||!valid(reputation.next)||reputation.next<0||reputation.next>100)throw Error('Réputation calculée invalide');
    c.reputation=reputation.next;
    const coach=adapters.coachRisk({confidence:c.coachConfidence,consecutiveLosses:Math.min(10,finish-1)});
    if(!coach||!valid(coach.risk)||coach.risk<0||coach.risk>100)throw Error('Risque entraîneur invalide');
    const coachChanged=coach.risk>=75&&random()<.45;
    if(coachChanged){c.coachConfidence=55;events.push({season,clubId:c.id,type:'coachChange'});}
    else c.coachConfidence=Math.max(0,Math.min(100,Math.round(c.coachConfidence+(finish<=3?6:-4))));
    const revenue=90000+Math.round(c.reputation*1200)+(state.length-finish)*4000;
    const operations=Math.round(125000+c.facilities*3500);
    if(!externalEconomy)c.cash=Math.max(0,Math.round(c.cash+revenue-operations));
    const proposed=adapters.facility({cash:c.cash,level:c.facilities,cost:60000+c.facilities*12000,weeks:1});
    if(!proposed||typeof proposed.affordable!=='boolean'||!valid(proposed.remaining))throw Error('Projet infrastructure invalide');
    if(!externalEconomy&&proposed.affordable&&c.facilities<10&&c.cash>200000&&finish<=Math.ceil(state.length/2)){
      c.cash=proposed.remaining;c.facilities++;events.push({season,clubId:c.id,type:'facility'});
    }
    const recruit=adapters.recruitment({cash:c.cash,wageRoom:c.wageRoom,needs:[],candidates:[]});
    if(!recruit||typeof recruit.action!=='string')throw Error('Décision IA invalide');
    const row={clubId:c.id,finish,cash:Math.round(c.cash),reputation:c.reputation,facilities:c.facilities,coachChanged,recruitmentDecision:recruit.action};
    seasonRows.push(row);
    if(!valid(row.cash)||row.cash<0||!valid(row.reputation))throw Error('État économique invalide');
   }
   const standings=seasonRows.sort((a,b)=>a.finish-b.finish);
   const world=adapters.world(standings.map(r=>({id:r.clubId,rating:Math.round(r.reputation),minutes:1000,tries:state.length-r.finish})));
   if(!Array.isArray(world))throw Error('Récompenses invalides');
   history.push({season,champion:standings[0].clubId,standings:standings.map(r=>({...r})),awards:world.map(x=>({...x}))});
  }
  return {seed,seasons,clubs:state.map(c=>({...c})),history,events};
 }
 return Object.freeze({rng,simulate});
});
