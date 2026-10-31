'use strict';
const assert=require('node:assert/strict');
const files=['top14-a','top14-b','prod2-a','prod2-b'].map(n=>require('../modding/data03/'+n+'.json'));
const clubs=files.flatMap(f=>f.clubs);
assert.equal(clubs.length,30);
assert.equal(new Set(clubs.map(c=>c.league+':'+c.club)).size,30);
assert.equal(clubs.filter(c=>c.league==='top14').length,14);
assert.equal(clubs.filter(c=>c.league==='prod2').length,16);
const entries=clubs.flatMap(c=>c.players.map(p=>({...p,club:c.club})));
assert.equal(entries.length,1592);
assert.equal(new Set(entries.map(p=>p.id)).size,entries.length);
for(const f of files){assert.equal(f.date,'2026-10-31');assert.equal(f.historicalAsOfJuly1Verified,false)}
for(const c of clubs){assert.ok(c.source.endsWith('/effectif-staff'));assert.ok(c.players.length>=30);for(const p of c.players){assert.match(p.id,/^lnr:\d+$/);assert.ok(p.name);assert.match(p.url,/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\/\d+-/) }}
console.log('DATA-03 PASS 30 clubs 1592 profils joueurs LNR uniques; historique juillet non certifie');
