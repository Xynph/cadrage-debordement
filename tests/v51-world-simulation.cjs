'use strict';
const assert=require('node:assert/strict');
const engine=require('../dist/world-simulation.js');
// Adaptateurs contractuels déterministes : les PR V46-V50 ne sont pas dans main.
const adapters={
 reputation:({current,leagueFinish,leagueSize,champion})=>({next:Math.min(100,Math.round(current*.8+((leagueSize-leagueFinish)/(leagueSize-1)*70+(champion?20:0))*.2))}),
 coachRisk:({confidence,consecutiveLosses})=>({risk:Math.min(100,Math.round((100-confidence)*.65+consecutiveLosses*3))}),
 facility:({cash,level,cost,weeks})=>({affordable:cash>=cost,remaining:cash-cost,nextLevel:Math.min(10,level+1)}),
 recruitment:()=>({action:'conserve',candidate:null}),
 world:players=>players.slice().sort((a,b)=>b.rating-a.rating).slice(0,5).map(p=>({id:p.id,score:p.rating}))
};
const clubs=Array.from({length:14},(_,i)=>({id:'club-'+i,cash:500000+i*10000,reputation:40+i*3,wageRoom:10000,facilities:2+i%4,coachConfidence:65}));
for(const years of [10,15]){
 const a=engine.simulate({clubs,seasons:years,seed:2026,adapters});
 const b=engine.simulate({clubs,seasons:years,seed:2026,adapters});
 assert.deepEqual(a,b);
 assert.equal(a.history.length,years);
 assert.equal(a.history.every(y=>y.standings.length===14&&new Set(y.standings.map(x=>x.clubId)).size===14),true);
 assert.equal(a.clubs.every(c=>c.cash>=0&&c.reputation>=0&&c.reputation<=100&&c.facilities<=10),true);
 assert.equal(a.history.every(y=>y.standings[0].clubId===y.champion),true);
 assert.equal(a.history.every(y=>y.awards.length===5),true);
 assert.equal(clubs[0].cash,500000);
}
assert.notDeepEqual(engine.simulate({clubs,seasons:10,seed:1,adapters}).history,engine.simulate({clubs,seasons:10,seed:2,adapters}).history);
assert.throws(()=>engine.simulate({clubs,seasons:16,adapters}),RangeError);
assert.throws(()=>engine.simulate({clubs:[clubs[0],clubs[0]],adapters}),RangeError);
assert.throws(()=>engine.simulate({clubs,seasons:10,seed:1,adapters:{}}),TypeError);
console.log(JSON.stringify({passed:true,clubs:14,seasons:[10,15],checks:['déterminisme','variabilité des graines','plafonds','entraîneurs','réputation','infrastructures','récompenses','entrées inchangées','rejets invalides']}));
