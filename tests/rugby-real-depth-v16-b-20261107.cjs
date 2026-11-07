'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const V=require('../tools/rugby-real-v16/audit.cjs');
test('V16 seed1907: six paired native career transitions isolate AI depth, unattended user and verified positions',{timeout:175000},()=>{
 const r=V.runCareer(1907);assert.equal(r.length,2);
 for(const arm of r){assert.equal(arm.openings.length,7);assert.equal(arm.years.length,6);assert.equal(arm.nativeMatches,1122);assert.ok(arm.openings.every(s=>s.length===14));assert.ok(arm.openings.every(s=>s.filter(c=>c.user).length===1));assert.equal(arm.openings[0].reduce((n,c)=>n+c.roster,0),805);}
 assert.equal(JSON.stringify(r[0].openings[0].map(c=>c.players.map(p=>p.id))),JSON.stringify(r[1].openings[0].map(c=>c.players.map(p=>p.id))));
 if(process.env.V16_RESULTS_DIR){fs.mkdirSync(process.env.V16_RESULTS_DIR,{recursive:true});fs.writeFileSync(path.join(process.env.V16_RESULTS_DIR,'career-1907.json'),JSON.stringify(r));}
});
