'use strict';
const assert=require('node:assert/strict');
const bridge=require('../dist/world-finance.js');
const adapters={reputation:({current})=>({next:current}),coachRisk:()=>({risk:0}),
 facility:({cash,cost})=>({affordable:cash>=cost,remaining:cash-cost}),
 recruitment:()=>({action:'conserve'}),world:()=>[]};
const clubs=Array.from({length:14},(_,i)=>({id:'c'+i,cash:i<4?800000:i<10?90000:-100000,
 debt:i>=10?90000:0,reputation:40+i*3,wageRoom:10000,facilities:3,coachConfidence:60}));
const profiles=Object.fromEntries(clubs.map((c,i)=>[c.id,{revenue:i<4?320000:i<10?170000:60000,
 baseCosts:i<4?140000:i<10?175000:290000,investment:25000,repayment:4000}]));
const options={clubs,seed:1057,adapters,profiles};
const whole=bridge.simulate({...options,seasons:15});
const first=bridge.simulate({...options,seasons:5});
const snapshot=JSON.parse(JSON.stringify(first.checkpoint));
const resumed=bridge.simulate({...options,seasons:15,checkpoint:snapshot});
assert.deepEqual(resumed.history,whole.history);
assert.deepEqual(resumed.clubs,whole.clubs);
assert.deepEqual(resumed.events,whole.events);
assert.equal(resumed.checkpoint.completed,15);
assert.equal(snapshot.completed,5,'checkpoint initial inchangé');
assert.equal(first.history.length,5);
assert.equal(clubs[10].cash,-100000,'carrière source inchangée');
assert.ok(whole.history.some(y=>y.standings.some(r=>r.cash<0)));
assert.ok(whole.history.some(y=>y.standings.some(r=>r.investmentDeferred>0)));
for(const corrupt of [
 {...snapshot,version:99},
 {...snapshot,seed:999},
 {...snapshot,completed:15},
 {...snapshot,clubs:[...snapshot.clubs.slice(0,-1),{...snapshot.clubs[13],debt:-1}]},
 {...snapshot,history:snapshot.history.slice(1)}
]) assert.throws(()=>bridge.simulate({...options,seasons:15,checkpoint:corrupt}),RangeError);
console.log('V51 reprise par checkpoint: 14 clubs, 5 + 10 saisons identiques à 15 saisons');
