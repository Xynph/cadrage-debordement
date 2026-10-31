'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),finance=require('../dist/world-finance.js');
const seeds=Array.from({length:32},(_,i)=>1777+i*6553);
const common={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
function clubs(profile){return Array.from({length:14},(_,i)=>({id:'c'+i,cash:profile==='crisis'?(i<7?-120000:50000):profile==='wealthy'?500000:180000,debt:profile==='crisis'?(i<7?100000:0):0,reputation:profile==='wealthy'?70:55,wageRoom:15000,facilities:3,coachConfidence:60}));}
function round(n){return Math.round(n*10000)/10000;}
function audit(profile,strength){
 const adapters={...common,reputation:p=>{const v=rep.update(p);return {...v,next:Math.max(0,Math.min(100,p.current+(v.next-p.current)*strength))}}};
 const years=Array.from({length:15},(_,i)=>({season:i+1,deficits:0,restrictions:0,investmentPaid:0,coachChanges:0,champions:[]}));
 let titlesConcentration=0,distinctChampions=0,coachEventCount=0,investmentEventCount=0,paidEventCount=0,decisions=0,transfers=0;
 for(const seed of seeds){
  const fixture=clubs(profile),original=JSON.stringify(fixture),options={clubs:fixture,seasons:15,seed,adapters};
  const result=finance.simulate(options),titles=new Map();
  assert.equal(JSON.stringify(fixture),original,'initial clubs must be unchanged');
  assert.equal(result.history.length,15);
  for(const [idx,h] of result.history.entries()){
   assert.equal(h.standings.length,14);
   assert.equal(h.standings.find(r=>r.finish===1).clubId,h.champion);
   titles.set(h.champion,(titles.get(h.champion)||0)+1);
   years[idx].champions.push(h.champion);
   for(const row of h.standings){
    assert.ok(Number.isFinite(row.cash)&&Number.isFinite(row.debt)&&row.debt>=0);
    assert.ok(Number.isFinite(row.reputation)&&row.reputation>=0&&row.reputation<=100);
    assert.ok(Number.isFinite(row.investmentPaid)&&row.investmentPaid>=0);
    assert.ok(row.investmentPaid===0||row.restriction==='normal');
    years[idx].deficits+=Number(row.cash<0);
    years[idx].restrictions+=Number(row.restriction!=='normal');
    years[idx].investmentPaid+=row.investmentPaid;
    decisions+=Number(typeof row.recruitmentDecision==='string');
    paidEventCount+=Number(row.investmentPaid>0);
   }
  }
  const events=result.events;
  for(const ev of events){
   assert.ok(Number.isInteger(ev.season)&&ev.season>=1&&ev.season<=15);
   if(ev.type==='coachChange'){coachEventCount++;years[ev.season-1].coachChanges++;}
   if(ev.type==='facility')investmentEventCount++;
   if(ev.type==='transferSigned')transfers++;
  }
  assert.equal(events.filter(e=>e.type==='coachChange').length,result.history.flatMap(y=>y.standings).filter(r=>r.coachChanged===true).length);
  assert.equal(events.filter(e=>e.type==='facility').length,result.history.flatMap(y=>y.standings).filter(r=>r.investmentPaid>0).length);
  titlesConcentration+=Math.max(...titles.values())/15;distinctChampions+=titles.size;
  const partial=finance.simulate({...options,seasons:9});
  const resumed=finance.simulate({...options,checkpoint:partial.checkpoint});
  assert.deepEqual(resumed.history,result.history);assert.deepEqual(resumed.events,result.events);assert.deepEqual(resumed.clubs,result.clubs);
 }
 assert.equal(transfers,0,'lab engine must not claim completed transfers');
 assert.equal(investmentEventCount,paidEventCount);
 const output={profile,strength,seasons:15,seeds:seeds.length,dominantShare:round(titlesConcentration/seeds.length),distinctChampions:round(distinctChampions/seeds.length),
  deficitRate:round(years.reduce((a,v)=>a+v.deficits,0)/(seeds.length*15*14)),restrictionRate:round(years.reduce((a,v)=>a+v.restrictions,0)/(seeds.length*15*14)),
  investmentPaid:years.reduce((a,v)=>a+v.investmentPaid,0),coachEventCount,investmentEventCount,recruitmentDecisionCount:decisions,signedTransfers:transfers,
  years:years.map(({champions,...year})=>({...year,uniqueChampions:new Set(champions).size}))};
 return output;
}
const scenarios=[];
for(const profile of ['baseline','crisis','wealthy'])for(const strength of [.15,.25,1])scenarios.push(audit(profile,strength));
assert.equal(scenarios.length,9);
assert.ok(scenarios.every(r=>r.years.length===15&&r.recruitmentDecisionCount===32*15*14));
const summary=scenarios.map(({years,...entry})=>entry);
if(process.env.CD_V54_REPORT)require('node:fs').writeFileSync(process.env.CD_V54_REPORT,JSON.stringify({schemaVersion:1,scenarios},null,2)+'\n');
console.log('V54 SCENARIO AUDIT OK '+JSON.stringify(summary));
