'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const seeds=Array.from({length:20},(_,i)=>101+i*7919);
const clubs=Array.from({length:14},(_,i)=>({id:'club-'+i,cash:i<4?550000:i<10?110000:-45000,debt:i<10?0:65000,reputation:40+i*3,wageRoom:15000,facilities:3,coachConfidence:60}));
const adapters={reputation:rep.update,coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
function round(v){return Math.round(v*100)/100;}
function run(seed){
 const result=bridge.simulate({clubs,seasons:15,seed,adapters});
 const champions=new Map(),coachConfidence=[],yearly=[];
 let deficitClubSeasons=0,restrictedClubSeasons=0,invested=0,investmentEvents=0,negativeDebt=0;
 for(const h of result.history){
  champions.set(h.champion,(champions.get(h.champion)||0)+1);
  let deficits=0,restricted=0,annualInvestment=0;
  for(const r of h.standings){
   assert.ok(Number.isFinite(r.cash)&&Number.isFinite(r.debt)&&r.debt>=0,'finance non finie / dette negative');
   assert.ok(Number.isFinite(r.reputation)&&r.reputation>=0&&r.reputation<=100,'reputation hors bornes');
   assert.ok(Number.isFinite(r.facilities)&&r.facilities>=1&&r.facilities<=10,'installations invalides');
   if(r.cash<0){deficits++;deficitClubSeasons++;}
   if(r.restriction!=='normal'){restricted++;restrictedClubSeasons++;}
   annualInvestment+=r.investmentPaid||0;invested+=r.investmentPaid||0;
   if(r.debt<0)negativeDebt++;
  }
  yearly.push({season:h.season,deficits,restricted,investment:annualInvestment,champion:h.champion});
 }
 for(const c of result.clubs){assert.ok(Number.isFinite(c.coachConfidence));coachConfidence.push(c.coachConfidence);}
 investmentEvents=result.events.filter(e=>e.type==='facility').length;
 const counts=[...champions.values()].sort((a,b)=>b-a);
 return {seed,titles:counts[0],distinctChampions:champions.size,topClubShare:round(counts[0]/15),
  deficitClubSeasons,restrictedClubSeasons,invested,investmentEvents,negativeDebt,
  finalCoachConfidenceAverage:round(coachConfidence.reduce((a,b)=>a+b,0)/coachConfidence.length),yearly};
}
const before=JSON.stringify(clubs),first=seeds.map(run),again=seeds.map(run);
assert.deepEqual(first,again,'non-determinisme entre deux campagnes');
assert.equal(JSON.stringify(clubs),before,'mutation de la fixture');
const summary={seeds:seeds.length,seasonsPerSeed:15,clubs:clubs.length,clubSeasons:seeds.length*15*clubs.length,
 avgUniqueChampions:round(first.reduce((s,r)=>s+r.distinctChampions,0)/first.length),
 avgLeaderTitleShare:round(first.reduce((s,r)=>s+r.topClubShare,0)/first.length),
 maxLeaderTitleShare:Math.max(...first.map(r=>r.topClubShare)),
 deficitClubSeasonRate:round(first.reduce((s,r)=>s+r.deficitClubSeasons,0)/(seeds.length*15*clubs.length)),
 restrictedClubSeasonRate:round(first.reduce((s,r)=>s+r.restrictedClubSeasons,0)/(seeds.length*15*clubs.length)),
 investmentTotal:first.reduce((s,r)=>s+r.invested,0),
 facilityEvents:first.reduce((s,r)=>s+r.investmentEvents,0),
 finalCoachConfidenceAverage:round(first.reduce((s,r)=>s+r.finalCoachConfidenceAverage,0)/first.length),
 negativeDebtCount:first.reduce((s,r)=>s+r.negativeDebt,0)};
assert.equal(summary.negativeDebtCount,0);
assert.ok(summary.avgUniqueChampions>=1&&summary.avgUniqueChampions<=14);
assert.ok(summary.deficitClubSeasonRate>=0&&summary.deficitClubSeasonRate<=1);
assert.ok(summary.restrictedClubSeasonRate>=0&&summary.restrictedClubSeasonRate<=1);
assert.ok(summary.investmentTotal>=0);
const report={summary,perSeed:first};
const dest=process.env.CD_BENCH_REPORT;
if(dest)fs.writeFileSync(path.resolve(dest),JSON.stringify(report,null,2)+'\n');
console.log('PASS equilibrium V46-V51: '+JSON.stringify(summary));
