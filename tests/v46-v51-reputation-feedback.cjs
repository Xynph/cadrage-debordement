'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const seeds=Array.from({length:20},(_,i)=>101+i*7919);
const clubs=()=>Array.from({length:14},(_,i)=>({id:'club-'+i,cash:160000,debt:0,reputation:60,wageRoom:15000,facilities:3,coachConfidence:60}));
const common={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
function measure(reputation){
 const shares=[],unique=[];
 for(const seed of seeds){const r=bridge.simulate({clubs:clubs(),seasons:15,seed,adapters:{...common,reputation}});
 const counter=new Map();for(const y of r.history)counter.set(y.champion,(counter.get(y.champion)||0)+1);
 shares.push(Math.max(...counter.values())/15);unique.push(counter.size);}
 const avg=a=>Math.round(a.reduce((s,x)=>s+x,0)/a.length*10000)/10000;
 return {dominantShare:avg(shares),uniqueChampions:avg(unique)};
}
const actual=measure(rep.update);
const frozen=measure(({current})=>({next:current}));
assert.deepEqual(actual,measure(rep.update));
assert.deepEqual(frozen,measure(({current})=>({next:current})));
console.log('DIAGNOSTIC REPUTATION V51: '+JSON.stringify({actual,frozen,delta:Math.round((frozen.dominantShare-actual.dominantShare)*10000)/10000}));
