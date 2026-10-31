'use strict';
const assert=require('node:assert/strict');
const bridge=require('../dist/world-finance.js');
const clubs=Array.from({length:14},(_,i)=>({id:'c'+i,cash:i<4?750000:i<10?100000:-60000,debt:i<10?0:40000,reputation:45+i*2,wageRoom:10000,facilities:3,coachConfidence:65}));
const adapters={reputation:({current})=>({next:current}),coachRisk:()=>({risk:0}),facility:({cash,cost})=>({affordable:cash>=cost,remaining:cash-cost}),recruitment:()=>({action:'conserve'}),world:()=>[]};
const profiles=Object.fromEntries(clubs.map((c,i)=>[c.id,{revenue:i<4?280000:i<10?160000:70000,baseCosts:i<4?140000:i<10?175000:300000,investment:30000,repayment:3000}]));
const options={clubs,seasons:15,seed:987,adapters,profiles};
const whole=bridge.simulate(options);
assert.equal(whole.history.length,15);
const finalRows=new Map(whole.history.at(-1).standings.map(r=>[r.clubId,r]));
for(const club of whole.clubs){
 const row=finalRows.get(club.id);
 assert.equal(row.facilities,club.facilities,'infrastructure du bilan egale au club');
 assert.equal(row.cash,club.cash,'tresorerie du bilan egale au club');
 assert.equal(row.debt,club.debt,'dette du bilan egale au club');
}

for(const cut of [1,2,4,7,10,14]){
 const piece=bridge.simulate({...options,seasons:cut});
 const copy=JSON.parse(JSON.stringify(piece.checkpoint));
 const before=JSON.stringify(copy);
 const resumed=bridge.simulate({...options,checkpoint:copy});
 assert.deepEqual(resumed.history,whole.history,'historique saison '+cut);
 assert.deepEqual(resumed.clubs,whole.clubs,'finances saison '+cut);
 assert.deepEqual(resumed.events,whole.events,'evenements saison '+cut);
 assert.equal(JSON.stringify(copy),before,'checkpoint source non modifie');
}
assert.equal(clubs[10].cash,-60000);
assert.ok(whole.history.some(y=>y.standings.some(r=>r.cash<0)),'deficits visibles');
assert.ok(whole.clubs.every(c=>c.facilities>=3&&c.facilities<=10&&c.debt>=0));
const snap=bridge.simulate({...options,seasons:5}).checkpoint;
const mutations=[
 {...snap,seed:-1},
 {...snap,completed:0},
 {...snap,history:snap.history.slice(0,4)},
 {...snap,penalties:{...snap.penalties,c0:-1}}
];
for(const bad of mutations)assert.throws(()=>bridge.simulate({...options,checkpoint:bad}));
console.log('V51: 6 points de reprise 1-14 saisons, 14 clubs, 15 saisons');
