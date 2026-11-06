'use strict';
// E2: pure read-only reconciliation of native career snapshots.
// No reference to browser state S, no writes to game saves.
(function(root,factory){const api=factory();if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.CDEconomyV2Shadow=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
 const assert=(ok,msg)=>{if(!ok)throw Error(msg)};
 const isMoney=n=>Number.isSafeInteger(n);
 function capture(state){
  assert(state&&Number.isSafeInteger(state.season)&&Array.isArray(state.clubs)&&Number.isInteger(state.manager),'Invalid legacy state');
  const ids=new Set(),clubs=state.clubs.map(c=>{assert(Number.isInteger(c.id)&&!ids.has(c.id)&&isMoney(c.cash),'Invalid club snapshot');ids.add(c.id);return {id:c.id,cash:c.cash}});
  assert(ids.has(state.manager),'Manager missing');
  return {season:state.season,round:state.round,phase:state.phase,manager:state.manager,clubs};
 }
 function observe(before,after,entries=[],label='step'){
  const a=capture(before),b=capture(after);
  assert(a.clubs.length===b.clubs.length&&a.manager===b.manager,'Club ownership changed: separate snapshot required');
  const byId=new Map(a.clubs.map(x=>[x.id,x.cash]));
  assert(b.clubs.every(x=>byId.has(x.id)),'Club set changed');
  assert(Array.isArray(entries)&&typeof label==='string'&&label.length>0,'Invalid observation');
  // Source ledger only records the human-managed club, not all AI money movements.
  const humanEntries=entries.map(e=>{assert(e&&isMoney(e.amount)&&typeof e.title==='string','Invalid ledger entry');return {title:e.title,amount:e.amount}});
  const journalTotal=humanEntries.reduce((s,e)=>s+e.amount,0);
  assert(isMoney(journalTotal),'Journal overflow');
  const rows=b.clubs.map(c=>{
   const delta=c.cash-byId.get(c.id);
   assert(isMoney(delta),'Invalid cash delta');
   const explained=c.id===a.manager?journalTotal:0;
   return {clubId:c.id,opening:byId.get(c.id),closing:c.cash,delta,explained,unexplained:delta-explained,source:c.id===a.manager?'manager-ledger':'ai-opaque'};
  });
  const human=rows.find(r=>r.clubId===a.manager);
  return {label,seasonBefore:a.season,seasonAfter:b.season,roundBefore:a.round,roundAfter:b.round,phaseBefore:a.phase,phaseAfter:b.phase,manager:a.manager,rows,managerEntries:humanEntries,managerReconciled:human.unexplained===0,unexplainedClubs:rows.filter(r=>r.unexplained!==0).map(r=>r.clubId)};
 }
 function summarize(items){
  assert(Array.isArray(items),'Invalid observations');
  const periods=items.length,unexplainedSteps=items.filter(x=>x.rows.some(r=>r.unexplained!==0)).length,managerFailures=items.filter(x=>!x.managerReconciled).length;
  const unknownByClub=new Map();
  for(const o of items)for(const r of o.rows)if(r.unexplained!==0)unknownByClub.set(r.clubId,(unknownByClub.get(r.clubId)||0)+Math.abs(r.unexplained));
  return {periods,managerFailures,unexplainedSteps,unexplainedClubs:[...unknownByClub].map(([clubId,absoluteResidual])=>({clubId,absoluteResidual})),allClubsReconciled:unexplainedSteps===0};
 }
 return Object.freeze({capture,observe,summarize});
});