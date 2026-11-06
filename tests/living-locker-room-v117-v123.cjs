'use strict';
const assert=require('node:assert/strict');
const api=require('../dist/living-locker-room-v117-v123.js');
const make=()=>({
 season:1,phase:'league',club:0,round:4,morale:75,trust:70,trained:false,live:null,
 economy:{week:4},
 manager:{inbox:[],serial:0},
 clubs:[{players:[
  {id:'p1',name:'Louis Martin',age:27,rating:77,condition:93,injury:0,contractEnd:3,dev:{minutes:220},satisfaction:{score:34}},
  {id:'p2',name:'Hugo Colin',age:22,rating:74,condition:87,injury:0,contractEnd:2,dev:{minutes:165},satisfaction:{score:69}},
  {id:'p3',name:'Paul Morel',age:31,rating:79,condition:89,injury:0,contractEnd:1,dev:{minutes:360},satisfaction:{score:80}}
 ]}]
});
{
 const s=make(),a=api.weeklyEvent(s),b=api.weeklyEvent(JSON.parse(JSON.stringify(s)));
 assert.deepEqual(a,b,'deterministic event');
 assert.equal(a.kind,'tension');
 assert.deepEqual(api.personality(s.clubs[0].players[0]),api.personality({...s.clubs[0].players[0]}));
 assert.ok(api.panel(s).includes('Monde vivant'));
 assert.equal(s.livingLockerRoom,undefined,'render must not mutate old saves');
}
{
 const s=make(),messages=[];
 assert.equal(api.apply(s,'responsabiliser',{save:()=>true,message:(...x)=>messages.push(x)}),true);
 assert.equal(s.livingLockerRoom.history.length,1);
 assert.equal(s.livingLockerRoom.commitments.length,1);
 assert.equal(s.clubs[0].players[0].satisfaction.score,36);
 assert.equal(s.morale,77);
 assert.equal(messages.length,1);
 assert.equal(api.apply(s,'ecouter',{save:()=>true}),false,'one event per week');
 s.economy.week=6;
 s.clubs[0].players[0].dev.minutes+=80;
 assert.equal(api.settle(s).length,1);
 assert.equal(s.livingLockerRoom.commitments[0].status,'honored');
 assert.equal(api.settle(s).length,0,'settlement idempotent');
 assert.equal(s.clubs[0].players[0].satisfaction.score,39);
 assert.equal(JSON.parse(JSON.stringify(s)).livingLockerRoom.history.length,1,'JSON save roundtrip');
}
{
 const s=make();
 const old=JSON.stringify(s);
 assert.equal(api.apply(s,'cadrer',{save:()=>false}),false);
 assert.equal(JSON.stringify(s),old,'save failure rollback');
}
{
 const s=make();
 assert.equal(api.apply(s,'ecouter',{save:()=>true}),true);
 assert.equal(s.morale,76);
 assert.equal(s.trust,70);
 assert.equal(s.clubs[0].players[0].satisfaction.score,38);
 s.live={finished:false};
 assert.equal(api.allowed(s),false);
}
{
 const s=make();
 assert.equal(api.apply(s,'responsabiliser',{save:()=>true}),true);
 s.economy.week=6;
 assert.equal(api.settle(s).length,1);
 assert.equal(s.livingLockerRoom.commitments[0].status,'broken');
 assert.equal(s.morale,75,'moral returns to baseline on unfulfilled commitment');
}
{
 const s=make(),old=JSON.stringify(s);
 assert.equal(api.apply(s,'invalid',{save:()=>true}),false);
 assert.equal(JSON.stringify(s),old);
 s.phase='ended';
 assert.equal(api.weeklyEvent(s),null);
}
{
 const s=make();
 for(let week=4;week<90;week++){
  s.economy.week=week;
  api.settle(s);
  api.apply(s,'ecouter',{save:()=>true});
 }
 assert.ok(s.livingLockerRoom.history.length<=80,'history bound');
 assert.doesNotThrow(()=>JSON.parse(JSON.stringify(s)),'long career save');
}
console.log('V117-V123: 7 suites PASS; legacy saves, rollback, context, decisions, commitments, idempotence, long seasons.');
