'use strict';
const assert=require('node:assert/strict');
const bridge=require('../dist/world-finance.js');
const clubs=Array.from({length:14},(_,i)=>({id:'club'+i,cash:i<4?750000:i<10?120000:-150000,debt:i<10?0:100000,reputation:38+i*3,wageRoom:10000,facilities:3,coachConfidence:65}));
const adapters={
 reputation:({current})=>({next:Math.min(100,current+1)}),
 coachRisk:()=>({risk:0}),
 facility:({cash})=>({affordable:false,remaining:cash}),
 recruitment:()=>({action:'conserve'}),
 world:()=>[]
};
const profiles=Object.fromEntries(clubs.map((c,i)=>[c.id,{revenue:i<4?320000:i<10?185000:90000,baseCosts:i<4?150000:i<10?180000:275000,investment:20000,repayment:5000}]));
for(const years of [10,15]){
 const input={clubs,seasons:years,seed:42,adapters,profiles};
 const a=bridge.simulate(input),b=bridge.simulate(input);
 assert.deepEqual(a,b);
 assert.equal(a.history.length,years);
 assert.equal(a.clubs.length,14);
 assert.equal(a.history.every(y=>y.standings.length===14),true);
 assert.equal(a.history.every(y=>y.standings.every(r=>Number.isFinite(r.cash)&&r.debt>=0)),true);
 assert.ok(a.clubs.some(c=>c.cash<0),'les déficits ne doivent pas être masqués');
 assert.ok(a.history.some(y=>y.standings.some(r=>r.restriction==='redressement')));
 assert.ok(a.history.some(y=>y.standings.some(r=>r.investmentDeferred>0)));
 assert.equal(clubs[10].cash,-150000);
}
const steady=bridge.simulate({clubs,seasons:15,seed:42,adapters,profiles});
assert.ok(steady.clubs.find(c=>c.id==='club0').cash>750000);
assert.ok(steady.clubs.find(c=>c.id==='club13').cash<0);
assert.throws(()=>bridge.simulate({clubs,seasons:16,adapters}),RangeError);
assert.throws(()=>bridge.simulate({clubs:[{...clubs[0],debt:-1},clubs[1]],adapters}),RangeError);
console.log(JSON.stringify({passed:true,clubs:14,seasons:[10,15],profiles:['aisé','modeste','déficitaire']}));
