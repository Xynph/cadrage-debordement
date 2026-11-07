'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const V=require('../tools/rugby-real-v16/audit.cjs');
test('V16 individual profiles e across opposition, fatigue, starter/bench/unavailable and signed doses',{timeout:170000},()=>{
 const rows=V.runPlayers(V.spec.players.slice(8,9).map(p=>p.id));assert.equal(rows.length,1);
 for(const p of rows){assert.equal(p.rows.length,4);for(const r of p.rows){assert.equal(r.controlSelfEqual,true);assert.equal(r.arms.length,4);if(r.kind==='starter')for(const a of r.arms)assert.equal(a.starts,48,'target must truly start every requested exposure');if(r.kind==='bench')for(const a of r.arms){assert.equal(a.starts,0,'target must truly be nominated on bench');assert.equal(a.nominated,48);assert.ok(a.appearances>0,'bench target must enter in some native matches');}if(r.kind==='unavailable')for(const a of r.arms){assert.equal(a.minutes,0);if(a.margin)assert.equal(a.margin.mean,0);}}}
 if(process.env.V16_RESULTS_DIR){fs.mkdirSync(process.env.V16_RESULTS_DIR,{recursive:true});fs.writeFileSync(path.join(process.env.V16_RESULTS_DIR,'individual-e.json'),JSON.stringify(rows));}
});
