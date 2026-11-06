'use strict';
// Read-only audit of native debt and contractual exposure. Not a booking system.
const assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs');
const E=require('./economy-v2-components.cjs');
function snapshot(g){
 return N.data(g,`({season:S.season,round:S.round,phase:S.phase,manager:S.club,
  clubs:S.clubs.map(c=>{const info=worldClub(c.id);return {
    id:c.id,name:c.name,cash:c.cash,debt:info?.debt??null,
    facilities:info?.facilities??null,
    wageWeekly:c.players.reduce((s,p)=>s+p.salary,0),
    contracts:c.players.filter(p=>Number.isInteger(p.contractEnd)).length,
    expiring:c.players.filter(p=>p.contractEnd===S.season).length,
    unknownEnd:c.players.filter(p=>!Number.isInteger(p.contractEnd)).length
  }}),
  pendingTalks:Object.keys(S.economy?.talks||{}).length,
  activeSponsor:S.careerManagement?.sponsor?.key??null,
  academyWeeklyDecision:S.careerManagement?.academyInvestment??null})`);
}
function annualDebt(before,after){
 assert.equal(after.season,before.season+1,'Expected season rollover');
 assert.equal(before.clubs.length,14);
 const rows=[];
 for(const b of before.clubs){
  const a=after.clubs.find(x=>x.id===b.id);
  assert(a&&Number.isFinite(b.debt)&&Number.isFinite(a.debt),'Missing debt snapshot');
  if(b.id===before.manager){
   assert.equal(a.debt,b.debt,'Manager debt changed without a native journal');
   rows.push({clubId:b.id,openingDebt:b.debt,closingDebt:a.debt,debtConverted:0,interest:0,repayment:0,source:'manager-unchanged'});
   continue;
  }
  const converted=Math.max(0,-b.cash),opening=b.debt+converted;
  const debtWithInterest=opening*1.04;
  // Mirrors documented inputs of worldNewSeason and the annual loan calculation,
  // independently reconstructed without mutating the native state.
  const capacity=Math.max(0,Math.max(0,b.cash)+2500000);
  const repayment=Math.min(250000,opening,debtWithInterest,capacity);
  const interest=debtWithInterest-opening;
  const expected=debtWithInterest-repayment;
  assert.ok(Math.abs(expected-a.debt)<1e-6,
   'Debt mismatch for club '+b.id+': expected '+expected+' observed '+a.debt);
  rows.push({clubId:b.id,openingDebt:b.debt,closingDebt:a.debt,
   debtConverted:converted,interest,repayment,source:'worldNewSeason+CDFinancialRecovery.annual'});
 }
 return rows;
}
function roundDebt(before,after){
 for(const b of before.clubs){
  const a=after.clubs.find(x=>x.id===b.id);
  assert(a&&a.debt===b.debt,'Unexpected midseason debt mutation: '+b.id);
 }
}
function exposures(snap){
 const x=snap.clubs.map(c=>({clubId:c.id,weeklyWage:c.wageWeekly,
  contractsWithEnd:c.contracts,expiringThisSeason:c.expiring,
  unknownContractEnd:c.unknownEnd,
  // Neither weekly wages nor contract counts are a booked payable balance.
  bookedPayable:null,estimatedFutureCommitment:null}));
 return {clubs:x,pendingNegotiations:snap.pendingTalks,
  sponsorChoice:snap.activeSponsor,academyWeeklyDecision:snap.academyWeeklyDecision,
  bookedLiabilityAvailable:false,reason:'Legacy model lacks a dated payable/obligation journal for all AI clubs'};
}
function round(g,stats){const before=snapshot(g),flow=E.auditedAction(g,()=>N.round(g,stats),'round'),after=snapshot(g);roundDebt(before,after);return {before,after,flow}}
function rollover(g){const before=snapshot(g),flow=E.auditedAction(g,()=>g.run('advanceSeason()'),'rollover'),after=snapshot(g);return {before,after,flow,debtRows:annualDebt(before,after)}}
module.exports={snapshot,annualDebt,roundDebt,exposures,round,rollover};
