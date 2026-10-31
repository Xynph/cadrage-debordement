'use strict';
// V52 : laboratoire longitudinal, aucune modification du jeu ni des sauvegardes.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const strengths=[0.15,0.25,0.4,1],seeds=Array.from({length:30},(_,i)=>73+i*7319);
const base={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
function fixture(uneven){return Array.from({length:14},(_,i)=>({id:'club-'+i,cash:uneven?(i<4?500000:i<10?110000:-50000):160000,debt:uneven&&i>=10?60000:0,reputation:uneven?39+i*3:60,wageRoom:15000,facilities:3,coachConfidence:60}));}
const round=x=>Math.round(x*10000)/10000;
function run(strength,uneven){
 const adapter={...base,reputation:p=>{const x=rep.update(p);return {...x,next:Math.max(0,Math.min(100,p.current+(x.next-p.current)*strength))}}};
 const byYear=Array.from({length:15},(_,i)=>({season:i+1,deficits:0,restricted:0,investments:0,coachChanges:0,reputationGap:0,champions:[]}));
 let dominate=0,unique=0,totalInvest=0,financialBreaches=0,careerCoachChanges=0,decisions=0,facilityQuotes=0;
 for(const seed of seeds){
  const clubs=fixture(uneven),input=JSON.stringify(clubs);
  const opts={clubs,seed,seasons:15,adapters:adapter};
  const sim=bridge.simulate(opts);
  const counts=new Map();
  assert.equal(JSON.stringify(clubs),input,'fixture initiale modifiee');
  assert.equal(sim.history.length,15);
  for(const [index,year] of sim.history.entries()){
   const point=byYear[index];
   const distinct=new Set(year.standings.map(r=>r.clubId));
   assert.equal(distinct.size,14);
   counts.set(year.champion,(counts.get(year.champion)||0)+1);
   point.champions.push(year.champion);
   const reputations=year.standings.map(r=>r.reputation);
   point.reputationGap+=Math.max(...reputations)-Math.min(...reputations);
   for(const r of year.standings){
    if(!Number.isFinite(r.cash)||!Number.isFinite(r.debt)||r.debt<0||!Number.isFinite(r.reputation)||r.reputation<0||r.reputation>100||!Number.isInteger(r.facilities)||r.facilities<1||r.facilities>10)financialBreaches++;
    point.deficits+=Number(r.cash<0);
    point.restricted+=Number(r.restriction!=='normal');
    point.investments+=r.investmentPaid||0;
    totalInvest+=r.investmentPaid||0;
    if(typeof r.recruitmentDecision==='string')decisions++;
   }
  }
  const changes=sim.events.filter(e=>e.type==='coachChange');
  careerCoachChanges+=changes.length;
  for(const e of changes)byYear[e.season-1].coachChanges++;
  facilityQuotes+=sim.events.filter(e=>e.type==='facility').length;
  dominate+=Math.max(...counts.values())/15;
  unique+=counts.size;
  const checkpoint=bridge.simulate({...opts,seasons:7}).checkpoint;
  const resumed=bridge.simulate({...opts,checkpoint});
  assert.deepEqual(resumed.history,sim.history,'reprise non deterministe');
  assert.deepEqual(resumed.clubs,sim.clubs);
 }
 assert.equal(financialBreaches,0,'etat financier invalide');
 const years=byYear.map(p=>({season:p.season,deficitRate:round(p.deficits/(14*seeds.length)),restrictionRate:round(p.restricted/(14*seeds.length)),investments:p.investments,coachChanges:p.coachChanges,reputationGap:round(p.reputationGap/seeds.length),differentSeasonChampions:new Set(p.champions).size}));
 return {strength,uneven,dominantShare:round(dominate/seeds.length),uniqueChampions:round(unique/seeds.length),
  finalReputationGap:years.at(-1).reputationGap,deficitRate:round(byYear.reduce((a,y)=>a+y.deficits,0)/(seeds.length*15*14)),
  restrictionRate:round(byYear.reduce((a,y)=>a+y.restricted,0)/(seeds.length*15*14)),investmentTotal:totalInvest,coachChanges:careerCoachChanges,
  facilityEvents:facilityQuotes,recruitmentDecisionRows:decisions,financialBreaches,years};
}
const scenarios=[];
for(const uneven of [false,true])for(const strength of strengths)scenarios.push(run(strength,uneven));
assert.equal(scenarios.length,8);
assert.ok(scenarios.every(s=>s.years.length===15&&s.financialBreaches===0));
assert.ok(scenarios.every(s=>s.recruitmentDecisionRows===0||s.recruitmentDecisionRows===seeds.length*15*14));
const summarize=s=>({strength:s.strength,uneven:s.uneven,dominantShare:s.dominantShare,champions:s.uniqueChampions,repGap:s.finalReputationGap,deficits:s.deficitRate,restrictions:s.restrictionRate,investment:s.investmentTotal,coachChanges:s.coachChanges,facilityEvents:s.facilityEvents,decisions:s.recruitmentDecisionRows});
const report={schemaVersion:1,seeds:seeds.length,seasons:15,clubs:14,scenarios,summary:scenarios.map(summarize)};
if(process.env.CD_V52_REPORT)fs.writeFileSync(process.env.CD_V52_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V52 CAREER LAB PASS '+JSON.stringify(report.summary));
