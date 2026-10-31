'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {build,decodeName,validateProfileName}=require('../tools/data06-all-players.cjs');
test('full real corpus has 30 clubs and 1592 stable unique IDs',()=>{
 const d=build();assert.equal(d.summary.clubs,30);assert.equal(d.players.length,1592);
 assert.equal(new Set(d.players.map(p=>p.id)).size,1592);
 assert.equal(d.summary.individualProfiles,240);assert.equal(d.summary.rosterOnly,1352);
});
test('all profiles preserve LNR URL, original club and explicit unknowns',()=>{
 const d=build();for(const p of d.players){
  assert.match(p.id,/^lnr:\d+$/);assert.match(p.url,/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\//);
  assert.equal(p.salary,null);assert.equal(p.clubBudget,null);assert.equal(p.gameRatingEstimate,null);
  assert.equal(p.historicalAsOfJuly1Verified,false);assert.equal(p.birthDate,null);
  if(!p.profileEnriched){assert.equal(p.ageReported,null);assert.equal(p.heightCm,null);assert.equal(p.weightKg,null)}
 }
});
test('no fabricated positions, game ratings or contracts',()=>{
 const d=build();assert.ok(d.players.every(p=>p.contractEnd===null&&p.actualPerformance===null));
 assert.equal(d.players.filter(p=>p.profileEnriched).length,240);
});

test('HTML entities are decoded and individual source names must match DATA-03',()=>{
 assert.equal(decodeName('Efitusi Tupola MA&#039;AFU'),"Efitusi Tupola MA'AFU");
 assert.doesNotThrow(()=>validateProfileName('Efitusi Tupola MA&#039;AFU',"Efitusi Tupola MA'AFU",'lnr:2219'));
 assert.throws(()=>validateProfileName('Jean EXEMPLE','Pierre EXEMPLE','lnr:123'),/Individual name mismatch/);
 assert.throws(()=>validateProfileName('Jean EXEMPLE',null,'lnr:123'),/Invalid player name/);
 const player=build().players.find(p=>p.id==='lnr:2219');
 assert.equal(player.name,"Efitusi Tupola MA'AFU");
 assert.equal(player.profileEnriched,true);
});
test('checked-in catalogue is the byte-for-byte deterministic build output',()=>{
 const generated=JSON.stringify(build(),null,2)+'\n';
 const saved=fs.readFileSync(path.join(__dirname,'../modding/data06/all-players-2026-2027.json'),'utf8');
 assert.equal(saved,generated);
});
