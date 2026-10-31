'use strict';
const assert=require('node:assert/strict');
const {build}=require('../tools/calendrier04-build.cjs');
const data=build();
assert.equal(data.fixtures.length,422);
assert.equal(data.coverage.top14,182);
assert.equal(data.coverage.prod2,240);
assert.equal(data.careerStart,'2026-07-01');
for(const [league,count,rounds] of [['top14',14,26],['prod2',16,30]]){
 const fixtures=data.fixtures.filter(x=>x.competition===league);
 const clubs=new Set(fixtures.flatMap(x=>[x.home,x.away]));
 assert.equal(clubs.size,count);
 for(let r=1;r<=rounds;r++){
  const matches=fixtures.filter(x=>x.round===r);
  assert.equal(matches.length,count/2);
  assert.equal(new Set(matches.flatMap(x=>[x.home,x.away])).size,count);
 }
 const pairs=new Set(fixtures.map(x=>x.home+'|'+x.away));
 assert.equal(pairs.size,count*(count-1));
 for(const f of fixtures)assert.ok(pairs.has(f.away+'|'+f.home));
}
for(const match of data.fixtures){
 assert.equal(match.score,null);
 assert.equal(match.officialKickoff,null);
 assert.equal(match.kickoffStatus,'simulated-not-official');
 assert.ok(match.simulatedKickoff.slice(0,10)>=match.windowStart);
 assert.ok(match.simulatedKickoff.slice(0,10)<=match.windowEnd);
 assert.ok(/T\d{2}:\d{2}:00\+0[12]:00$/.test(match.simulatedKickoff));
}
console.log('CALENDRIER-04 PASS: 182 + 240 = 422 confrontations officielles, doubles allers-retours et 422 horaires simules distincts.');
