'use strict';
const assert=require('node:assert/strict');
const map=require('../world-data/mapping01/real-to-alternative-2026-2027.json');
const alt=require('../world-data/univers01/alternative-2026-2027.json');
const real=require('../modding/data01/fr-rugby-2026-2027.research.json');
const players=require('../modding/data02/verified-official-arrivals-sample.json');
assert.equal(map.entries.length,30);
assert.equal(new Set(map.entries.map(x=>x.alternateId)).size,30);
assert.equal(new Set(map.entries.map(x=>x.realId)).size,30);
const am=new Map(alt.clubs.map(x=>[x.id,x]));
const rm=new Map(real.clubs.map(x=>[x.id,x]));
for(const e of map.entries){
 assert.equal(am.get(e.alternateId)?.name,e.alternateName);
 assert.equal(rm.get(e.realId)?.name,e.realName);
 assert.equal(e.competition,e.alternateId.includes('premiere')?'top14':'prod2');
 assert.equal(e.review,'requires-game-design-approval');
}
assert.equal(players.isFullRoster,false);
assert.equal(players.players.length,30);
assert.equal(new Set(players.players.map(x=>x.id)).size,30);
for(const p of players.players){
 assert.ok(rm.has(p.clubId));assert.ok(p.sourceUrl.startsWith('https://top14.lnr.fr/'));
 assert.equal(p.contractEnd,null);assert.equal(p.salary,null);
}
console.log(JSON.stringify({pass:true,mappings:30,verifiedArrivalExamples:30,completeRosters:false}));
