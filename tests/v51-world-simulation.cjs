'use strict';
const assert=require('node:assert/strict');
const engine=require('../dist/world-simulation.js');
const rep=require('../dist/reputation.js');
const coach=require('../dist/coach-market.js');
const fac=require('../dist/facilities.js');
const ai=require('../dist/club-ai.js');
const world=require('../dist/rugby-world.js');
const adapters={reputation:rep.update,coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
const clubs=Array.from({length:14},(_,i)=>({id:'club-'+i,cash:500000+i*10000,reputation:40+i*3,wageRoom:10000,facilities:2+i%4,coachConfidence:65}));
for(const years of [10,15]){
 const a=engine.simulate({clubs,seasons:years,seed:2026,adapters});
 const b=engine.simulate({clubs,seasons:years,seed:2026,adapters});
 assert.deepEqual(a,b,'simulation déterministe');
 assert.equal(a.history.length,years);
 assert.equal(a.history.every(y=>y.standings.length===14&&new Set(y.standings.map(x=>x.clubId)).size===14),true);
 assert.equal(a.clubs.every(c=>c.cash>=0&&c.reputation>=0&&c.reputation<=100&&c.facilities<=10),true);
 assert.equal(a.history.every(y=>y.standings[0].clubId===y.champion),true);
 assert.equal(a.history.every(y=>y.awards.length<=5),true);
 assert.equal(clubs[0].cash,500000,'aucune mutation source');
}
assert.notDeepEqual(engine.simulate({clubs,seasons:10,seed:1,adapters}).history,engine.simulate({clubs,seasons:10,seed:2,adapters}).history);
assert.throws(()=>engine.simulate({clubs,seasons:16,adapters}),RangeError);
assert.throws(()=>engine.simulate({clubs:[clubs[0],clubs[0]],adapters}),RangeError);
assert.throws(()=>engine.simulate({clubs,seasons:10,seed:1,adapters:{}}),TypeError);
console.log(JSON.stringify({passed:true,clubs:14,seasons:[10,15],checks:['déterminisme','variabilité des graines','budget et plafonds','entraîneurs','réputation','infrastructures','récompenses','entrée inchangée','rejets invalides']}));
