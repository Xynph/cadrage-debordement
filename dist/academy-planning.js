'use strict';
// V43 : planification de formation et détection, sans effet direct sur les joueurs.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDAcademyPlanning=api})(typeof globalThis==='object'?globalThis:null,function(){
 const finite=n=>typeof n==='number'&&Number.isFinite(n);
 function shortlist(players,{maxAge=21,minPotential=70,positions=[]}={}){
  if(!Array.isArray(players)||!Number.isInteger(maxAge)||maxAge<15||maxAge>40||
   !finite(minPotential)||minPotential<0||minPotential>100||!Array.isArray(positions)||positions.some(x=>typeof x!=='string'))
   throw new RangeError('Critères de détection invalides');
  return players.filter(p=>p&&typeof p.id==='string'&&typeof p.pos==='string'&&
   Number.isInteger(p.age)&&finite(p.potential)&&p.age<=maxAge&&p.potential>=minPotential&&
   (!positions.length||positions.includes(p.pos)))
   .map(p=>({id:p.id,pos:p.pos,age:p.age,potential:p.potential}))
   .sort((a,b)=>b.potential-a.potential||a.age-b.age||a.id.localeCompare(b.id));
 }
 function developmentPlan({budget,weeklyInvestment=0,weeks=26,academySize=0}){
  if(!finite(budget)||budget<0||!finite(weeklyInvestment)||weeklyInvestment<0||
   !Number.isInteger(weeks)||weeks<1||weeks>104||
   !Number.isInteger(academySize)||academySize<0||academySize>200)
   throw new RangeError('Plan de formation invalide');
  const cost=weeklyInvestment*weeks;
  return {cost,remaining:budget-cost,affordable:cost<=budget,
   spendingPerProspect:academySize?cost/academySize:null};
 }
 function positionalNeeds(roster,required){
  if(!Array.isArray(roster)||!required||typeof required!=='object'||Array.isArray(required))throw new RangeError('Effectif invalide');
  return Object.entries(required).map(([pos,count])=>{
   if(!Number.isInteger(count)||count<0)throw new RangeError('Besoin invalide');
   const available=roster.filter(p=>p&&p.pos===pos&&!p.injury).length;
   return {pos,required:count,available,missing:Math.max(0,count-available)};
  }).sort((a,b)=>b.missing-a.missing||a.pos.localeCompare(b.pos,'fr'));
 }
 return Object.freeze({shortlist,developmentPlan,positionalNeeds});
});
