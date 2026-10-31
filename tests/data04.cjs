'use strict';
const assert=require('node:assert/strict');
const names=['top14-a','top14-b','prod2-a','prod2-b'];
const clubs=names.flatMap(n=>require('../modding/data04/'+n+'.json').clubs);
const players=clubs.flatMap(c=>c.players);
assert.equal(clubs.length,30);
assert.equal(players.length,1592);
assert.equal(new Set(players.map(p=>p.id)).size,1592);
assert.equal(players.filter(p=>p.positionGroup).length,1592);
assert.equal(players.filter(p=>p.nationality!==null).length,1559);
assert.equal(clubs.filter(c=>c.league==='top14').length,14);
assert.equal(clubs.filter(c=>c.league==='prod2').length,16);
const reconciliation=require('../modding/data04/arrival-reconciliation.json');
assert.equal(reconciliation.arrivals.length,30);
assert.equal(reconciliation.arrivals.filter(x=>x.matched).length,21);
const profiles=require('../modding/data04/individual-profiles-verified.json');
assert.equal(profiles.players.length,3);
for(const p of profiles.players){assert.ok(p.url.startsWith('https://'));assert.match(p.height,/^\dm\d{2}$/);assert.ok(Number(p.weightKg)>0);assert.equal(p.dateOfBirth,null);}
console.log('DATA-04: 30 clubs, 1592 postes, 1559 nationalites, 3 mensurations, 21 rapprochements sur 30');
