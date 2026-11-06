'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const api=require('../dist/interclub-world-v124-v130.js');
function fixture(){
 return {season:1,round:0,phase:'league',club:0,clubs:[
 {id:0,name:'Bleus fictifs',abbr:'BLE',base:65},
 {id:1,name:'Rouges fictifs',abbr:'ROU',base:80},
 {id:2,name:'Verts fictifs',abbr:'VER',base:60}
 ]};
}
const m=(a,b,x,y)=>({pair:[a,b],score:[x,y],tries:[1,1]});
{
 const s=fixture(),plain=JSON.stringify(s);
 assert.equal(api.state(s).version,1);
 assert.equal(api.panel(s).includes('Rivalités et réactions'),true);
 assert.equal(JSON.stringify(s),plain,'read-only legacy save');
 assert.equal(api.profile(1).style,api.profile(1).style);
 assert.equal(api.accept(s,{pair:[0,0],score:[10,10]}),null,'reject invalid match');
 assert.equal(JSON.stringify(s),plain,'invalid record should never mutate');
}
{
 const s=fixture(),first=api.accept(s,m(0,1,22,20));
 assert.equal(first.type,'surprise','underdog victory context');
 assert.equal(first.winner,0);
 assert.equal(s.interclubWorld.pairs['0:1'].winsA,1);
 assert.equal(api.accept(s,m(0,1,22,20)),null,'duplicate stamp idempotent');
 assert.equal(s.interclubWorld.events.length,1);
 s.round=1;
 api.accept(s,m(1,0,28,25));
 s.round=2;
 api.accept(s,m(0,1,18,19));
 assert.equal(s.interclubWorld.pairs['0:1'].games,3);
 assert.ok(api.top(s)[0].tension>20,'rivalry evolves');
 assert.equal(api.top(s)[0].years.length,1);
 assert.equal(api.panel(s,true).includes('Échos du championnat'),true);
 assert.equal(JSON.parse(JSON.stringify(s)).interclubWorld.pairs['0:1'].games,3,'JSON roundtrip');
}
{
 const s=fixture();api.accept(s,m(1,0,39,12));
 const coach=s.interclubWorld.coaches['0'];
 assert.ok(coach.pressure>30&&coach.lastReaction.length>0);
 s.round++;api.accept(s,m(1,0,30,13));
 assert.equal(s.interclubWorld.coaches['0'].consecutiveLosses,2);
 const pressure=s.interclubWorld.coaches['0'].pressure;
 s.season=2;s.round=0;
 assert.equal(api.season(s,1),true);
 assert.ok(s.interclubWorld.coaches['0'].pressure<pressure);
 assert.equal(s.interclubWorld.years.length,1);
 assert.equal(api.season(s,1),false,'season summary idempotent');
}
{
 const s=fixture();
 const old=JSON.stringify(s);
 assert.equal(api.season(s,1),false,'old save without state untouched');
 assert.equal(JSON.stringify(s),old);
 s.phase='ended';
 assert.equal(api.accept(s,m(0,1,10,8)),null);
 assert.equal(JSON.stringify(s),old.replace('"phase":"league"','"phase":"ended"'));
}
{
 const s=fixture();const old=JSON.stringify(s);
 for(let y=1;y<=15;y++){
   s.season=y;s.phase='league';s.round=0;
   api.accept(s,m(0,1,15+y,17));
   s.round=1;api.accept(s,m(2,0,22,20));
   s.round=2;api.accept(s,m(1,2,19,18));
   s.season=y+1;
   assert.equal(api.season(s,y),true);
   assert.equal(JSON.parse(JSON.stringify(s)).interclubWorld.years.length,y);
 }
 assert.equal(s.interclubWorld.years.length,15);
 assert.equal(s.interclubWorld.pairs['0:1'].games,15);
 assert.equal(s.interclubWorld.events.length,45);
 assert.equal(JSON.parse(JSON.stringify(s)).interclubWorld.pairs['0:1'].winsA>=1,true);
 assert.notEqual(JSON.stringify(s),old);
}
{
 // Real integration: load native game and public saved-state APIs from the existing VM harness.
 const {context}=require('./harness.cjs');
 const test=context();
 test.run('start(0)');
 const legacy=test.run('JSON.stringify(createSaveDocument())');
 assert.equal(test.run('S.interclubWorld'),undefined);
 // New module's install is exercised by the same global objects as real game.js.
 vm.runInContext(fs.readFileSync(require('node:path').join(__dirname,'../dist/interclub-world-v124-v130.js'),'utf8'),test.ctx);
 assert.equal(test.run('typeof CDInterclubWorld'),'object');
 test.run('record({pair:[0,1],score:[24,19],tries:[2,2]})');
 assert.equal(test.run('S.interclubWorld.events.length'),1);
 const saved=test.run('JSON.stringify(createSaveDocument())');
 assert.equal(test.run('parseSaveDocument('+JSON.stringify(saved)+').state.interclubWorld.events.length'),1);
 assert.equal(test.run('parseSaveDocument('+JSON.stringify(legacy)+').state.interclubWorld'),undefined,'legacy JSON accepted');
 const before=test.run('JSON.stringify(S.interclubWorld)');
 test.run('S.phase="ended";S.round=26;advanceSeason()');
 assert.equal(test.run('S.interclubWorld.years.length'),1);
 assert.equal(test.run('S.interclubWorld.pairs["0:1"].games'),1);
 assert.ok(test.run('JSON.stringify(S.interclubWorld)')!==before);
}
console.log('V124-V130 PASS: deterministic sports context, persistent rivalries, 15 seasons, reactions, native save export/import and interseason.');
