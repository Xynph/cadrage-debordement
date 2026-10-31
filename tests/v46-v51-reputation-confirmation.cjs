'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const seeds=Array.from({length:80},(_,i)=>101+i*7919),strengths=[0.15,0.25,0.4,1];
const base={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
const fixture=uneven=>Array.from({length:14},(_,i)=>({id:'club-'+i,cash:uneven?(i<4?550000:i<10?110000:-45000):160000,debt:uneven?(i<10?0:65000):0,reputation:uneven?40+i*3:60,wageRoom:15000,facilities:3,coachConfidence:60}));
const round=x=>Math.round(x*10000)/10000;
function sample(strength,uneven){
 const adapter={...base,reputation:p=>{const r=rep.update(p);return {...r,next:Math.max(0,Math.min(100,p.current+(r.next-p.current)*strength))}}};
 let share=0,champions=0,deficits=0,restrictions=0,investment=0,coachChanges=0;
 for(const seed of seeds){
  const sim=bridge.simulate({clubs:fixture(uneven),seasons:15,seed,adapters:adapter});
  const titles=new Map();
  for(const season of sim.history){titles.set(season.champion,(titles.get(season.champion)||0)+1);for(const row of season.standings){
   deficits+=Number(row.cash<0);restrictions+=Number(row.restriction!=='normal');investment+=row.investmentPaid||0;
  }}
  share+=Math.max(...titles.values())/15;champions+=titles.size;coachChanges+=sim.events.filter(e=>e.type==='coachChange').length;
 }
 const denom=seeds.length*15*14;
 return {strength,uneven,dominantTitleShare:round(share/seeds.length),uniqueChampions:round(champions/seeds.length),
 deficitRate:round(deficits/denom),restrictionRate:round(restrictions/denom),investmentTotal:investment,coachChanges};
}
const results=[];
for(const uneven of [false,true])for(const strength of strengths)results.push(sample(strength,uneven));
assert.deepEqual(results.map(r=>[r.strength,r.uneven]),[false,true].flatMap(u=>strengths.map(s=>[s,u])));
assert.ok(results.every(r=>r.dominantTitleShare>=0&&r.dominantTitleShare<=1&&r.uniqueChampions>=1));
console.log('CONFIRMATION EQUILIBRAGE 80 GRAINES: '+JSON.stringify(results));
