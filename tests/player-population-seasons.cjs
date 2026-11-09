'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const h=context(),r=h.run,started=Date.now();r('start(0)');
const initial=r('aiRosterAccessibleCount()'),reference=r('S.aiRoster.population.referenceAccessible'),years=[];
let recruits=0,promotions=0,retired=0,graduates=0,emerged=0;const observedRetired=new Set();
for(let season=1;season<=12;season++){
 r('while(S.phase==="league")finishRound();while(S.phase!=="ended")finishRound()');
 assert.equal(r('S.season'),season);
 assert.equal(r('new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id))).size'),r('S.clubs.reduce((n,c)=>n+c.players.length,0)'));
 assert.equal(r('S.economy.freeAgents.every(p=>!p.academy&&p.age<p.dev.retireAge&&!S.clubs.some(c=>c.players.some(q=>q.id===p.id)))'),true);
 assert.equal(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 const row=JSON.parse(r('JSON.stringify({season:S.season,pros:S.clubs.reduce((n,c)=>n+c.players.length,0),available:S.economy.freeAgents.length,accessible:aiRosterAccessibleCount(),min:Math.min(...S.clubs.filter(c=>c.id!==S.club).map(c=>c.players.length)),max:Math.max(...S.clubs.filter(c=>c.id!==S.club).map(c=>c.players.length)),bytes:saveUtf8Bytes(JSON.stringify(createSaveDocument()))})'));
 years.push(row);
 recruits+=r('S.aiRoster.reports.filter(x=>x.season===S.season).reduce((n,x)=>n+x.recruited,0)');
 promotions+=r('S.aiRoster.reports.filter(x=>x.season===S.season).reduce((n,x)=>n+x.promoted+x.emergency,0)');
 for(const id of JSON.parse(r('JSON.stringify(S.development.retired.map(p=>p.id))')))if(!observedRetired.has(id)){observedRetired.add(id);retired++}
 graduates+=r('S.aiRoster.population.history.filter(x=>x.season===S.season).reduce((n,x)=>n+x.graduated,0)');
 emerged+=r('S.aiRoster.population.history.filter(x=>x.season===S.season).reduce((n,x)=>n+x.emerged,0)');
 assert.ok(row.available<=r('aiRosterFreeAgentLimit()'));
 assert.ok(row.bytes<8*1024*1024);
 if([5,10].includes(season)){
  const before=r('JSON.stringify(S)'),reload=context(JSON.parse(before));
  assert.equal(reload.run('JSON.stringify(S)'),before,'reopening preserves IDs, pool, contracts, origin and policy');
 }
 if(season<12)r('advanceSeason()');
}
assert.ok(recruits>0&&promotions>0&&retired>0&&graduates>0&&emerged>0,'all renewal paths must execute: '+JSON.stringify({recruits,promotions,retired,graduates,emerged,years}));
assert.ok(years.at(-1).min>=30,'renewal must maintain useful AI depth, not merely 23 emergency players');
assert.ok(years.at(-1).accessible>=reference,'professionals plus available candidates must not keep disappearing');
console.log(JSON.stringify({passed:true,initial,reference,recruits,promotions,retired,graduates,emerged,years,elapsedMs:Date.now()-started}));
