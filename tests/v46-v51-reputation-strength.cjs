'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const seeds=Array.from({length:20},(_,i)=>101+i*7919),adapters={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
const fixture=()=>Array.from({length:14},(_,i)=>({id:'club-'+i,cash:160000,debt:0,reputation:60,wageRoom:15000,facilities:3,coachConfidence:60}));
const round=x=>Math.round(x*10000)/10000;
function run(strength){
 let totalShare=0,totalChampions=0,totalDrift=0,totalDeficits=0;
 const adapt={...adapters,reputation:(p)=>{const r=rep.update(p);return {...r,next:Math.max(0,Math.min(100,p.current+(r.next-p.current)*strength))}}};
 for(const seed of seeds){
  const result=bridge.simulate({clubs:fixture(),seasons:15,seed,adapters:adapt}),count=new Map();
  for(const year of result.history){count.set(year.champion,(count.get(year.champion)||0)+1);totalDeficits+=year.standings.filter(r=>r.cash<0).length;}
  totalShare+=Math.max(...count.values())/15;totalChampions+=count.size;
  totalDrift+=result.clubs.reduce((sum,c)=>sum+Math.abs(c.reputation-60),0)/14;
 }
 return {strength,dominantTitleShare:round(totalShare/20),champions:round(totalChampions/20),reputationDrift:round(totalDrift/20),deficitRate:round(totalDeficits/(20*15*14))};
}
const data=[0,0.15,0.25,0.4,0.6,0.8,1].map(run);
assert.deepEqual(data,[0,0.15,0.25,0.4,0.6,0.8,1].map(run),'determinisme');
assert.ok(data.every(d=>d.dominantTitleShare>=0&&d.dominantTitleShare<=1&&d.champions>=1&&d.champions<=14));
console.log('EXPERIMENTATION AMORTISSEMENT REPUTATION V51: '+JSON.stringify(data));
