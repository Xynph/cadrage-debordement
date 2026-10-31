'use strict';
const assert=require('node:assert/strict');
const engine=require('../dist/world-simulation.js');
const {audit,compareSeeds}=require('../dist/world-audit.js');
const clubs=Array.from({length:14},(_,i)=>({id:'c'+i,cash:i===0?0:500000,reputation:35+i*3,wageRoom:5000,facilities:3,coachConfidence:60}));
const adapters={
 reputation:({current})=>({next:current}),
 coachRisk:()=>({risk:0}),
 facility:({cash})=>({affordable:false,remaining:cash}),
 recruitment:()=>({action:'conserve'}),
 world:()=>[]
};
const options={clubs,seasons:15,adapters};
const first=engine.simulate({...options,seed:7});
const report=audit(first);
assert.equal(report.seasons,15);
assert.equal(report.clubs.length,14);
assert.equal(report.clubs.reduce((n,c)=>n+c.titles,0),15);
assert.equal(report.clubs.reduce((n,c)=>n+c.topThree,0),45);
assert.equal(report.clubs.reduce((n,c)=>n+c.coachChanges,0),0);
assert.ok(report.titleConcentration>=1/15&&report.titleConcentration<=1);
assert.deepEqual(audit(first),audit(engine.simulate({...options,seed:7})));
assert.equal(clubs[0].cash,0);
const multi=compareSeeds(engine.simulate,options,[1,2,3,4,5,6,7,8,9,10]);
assert.equal(multi.samples.length,10);
assert.equal(multi.samples.every(s=>s.seasons===15),true);
assert.ok(multi.averageConcentration>=1/15&&multi.averageConcentration<=1);
assert.throws(()=>compareSeeds(engine.simulate,options,[1,1]),RangeError);
const corrupted=structuredClone(first);corrupted.history[0].standings[1].finish=1;
assert.throws(()=>audit(corrupted),RangeError);
console.log(JSON.stringify({passed:true,seasons:15,seeds:10,clubs:14,checks:['titres','podiums','trésorerie','événements','déterminisme','données corrompues']}));
