'use strict';
// Audit purement analytique des projections V51 : aucune mutation des carrières.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDWorldAudit=api})(typeof globalThis==='object'?globalThis:null,function(){
 function audit(result){
  if(!result||!Array.isArray(result.history)||!Array.isArray(result.clubs)||!Array.isArray(result.events))
   throw new TypeError('Simulation invalide');
  const summaries=new Map(),issues=[],seen=new Set();
  for(const club of result.clubs){
   if(!club||typeof club.id!=='string'||!club.id||seen.has(club.id))throw new RangeError('Club invalide');
   seen.add(club.id);
   summaries.set(club.id,{clubId:club.id,titles:0,topThree:0,coachChanges:0,investments:0,minCash:Infinity,maxCash:-Infinity,minReputation:Infinity,maxReputation:-Infinity,finalCash:club.cash});
  }
  for(let i=0;i<result.history.length;i++){
   const year=result.history[i];
   if(!year||year.season!==i+1||!Array.isArray(year.standings)||year.standings.length!==seen.size)throw new RangeError('Saison invalide');
   const ranks=new Set(),ids=new Set();
   for(const row of year.standings){
    if(!summaries.has(row.clubId)||ids.has(row.clubId)||!Number.isInteger(row.finish)||row.finish<1||row.finish>seen.size||ranks.has(row.finish))
     throw new RangeError('Classement incohérent');
    ids.add(row.clubId);ranks.add(row.finish);
    if(!Number.isFinite(row.cash)||!Number.isFinite(row.reputation)||!Number.isInteger(row.facilities))
     throw new RangeError('Mesure invalide');
    const s=summaries.get(row.clubId);
    if(row.finish===1)s.titles++;
    if(row.finish<=3)s.topThree++;
    s.minCash=Math.min(s.minCash,row.cash);s.maxCash=Math.max(s.maxCash,row.cash);
    s.minReputation=Math.min(s.minReputation,row.reputation);s.maxReputation=Math.max(s.maxReputation,row.reputation);
    if(row.cash===0)issues.push({season:year.season,clubId:row.clubId,type:'treasuryFloor'});
    if(row.reputation<0||row.reputation>100||row.facilities<1||row.facilities>10)issues.push({season:year.season,clubId:row.clubId,type:'outOfBounds'});
   }
   if(year.standings.find(r=>r.finish===1)?.clubId!==year.champion)throw new RangeError('Champion incohérent');
  }
  for(const event of result.events){
   if(!event||!summaries.has(event.clubId)||!Number.isInteger(event.season)||event.season<1||event.season>result.history.length)throw new RangeError('Événement invalide');
   if(event.type==='coachChange')summaries.get(event.clubId).coachChanges++;
   if(event.type==='facility')summaries.get(event.clubId).investments++;
  }
  const clubs=[...summaries.values()].map(s=>({...s,minCash:Number.isFinite(s.minCash)?s.minCash:null,maxCash:Number.isFinite(s.maxCash)?s.maxCash:null,minReputation:Number.isFinite(s.minReputation)?s.minReputation:null,maxReputation:Number.isFinite(s.maxReputation)?s.maxReputation:null}));
  return {seasons:result.history.length,clubs,issues,titleConcentration:result.history.length?Math.max(...clubs.map(c=>c.titles))/result.history.length:0};
 }
 function compareSeeds(simulate,options,seeds){
  if(typeof simulate!=='function'||!Array.isArray(seeds)||seeds.length<2||seeds.length>50||new Set(seeds).size!==seeds.length||seeds.some(s=>!Number.isInteger(s)||s<0||s>4294967295))
   throw new RangeError('Graines invalides');
  const samples=seeds.map(seed=>({seed,...audit(simulate({...options,seed}))}));
  return {samples,averageConcentration:samples.reduce((n,s)=>n+s.titleConcentration,0)/samples.length,treasuryFloorEvents:samples.reduce((n,s)=>n+s.issues.filter(x=>x.type==='treasuryFloor').length,0)};
 }
 return Object.freeze({audit,compareSeeds});
});
