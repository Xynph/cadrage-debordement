'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const adapters={reputation:rep.update,coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
const seeds=Array.from({length:20},(_,i)=>101+i*7919);
function clubs(equal){
 return Array.from({length:14},(_,i)=>({id:'club-'+i,cash:equal?160000:i<4?550000:i<10?110000:-45000,
 debt:equal?0:i<10?0:65000,reputation:equal?60:40+i*3,wageRoom:15000,facilities:3,coachConfidence:60}));
}
function campaign(equal){
 let shares=[],different=[],deficits=0,restricted=0,investments=0;
 for(const seed of seeds){
  const result=bridge.simulate({clubs:clubs(equal),seasons:15,seed,adapters});
  const titles=new Map();
  for(const year of result.history){
   titles.set(year.champion,(titles.get(year.champion)||0)+1);
   for(const row of year.standings){
    deficits+=Number(row.cash<0);restricted+=Number(row.restriction!=='normal');
    investments+=row.investmentPaid||0;
   }
  }
  shares.push(Math.max(...titles.values())/15);different.push(titles.size);
 }
 const mean=x=>Math.round(x.reduce((a,b)=>a+b,0)/x.length*10000)/10000;
 return {topShare:mean(shares),uniqueChampions:mean(different),deficitRate:Math.round(deficits/(20*15*14)*10000)/10000,
 restrictedRate:Math.round(restricted/(20*15*14)*10000)/10000,investmentTotal:investments};
}
const uneven=campaign(false),equal=campaign(true);
assert.deepEqual(campaign(false),uneven);
assert.deepEqual(campaign(true),equal);
assert.ok(uneven.topShare>=0&&uneven.topShare<=1&&equal.topShare>=0&&equal.topShare<=1);
console.log('BENCH FIXTURE BASELINE VS EQUAL: '+JSON.stringify({uneven,equal,deltaTopShare:Math.round((equal.topShare-uneven.topShare)*10000)/10000}));
