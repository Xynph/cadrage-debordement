'use strict';
const assert=require('node:assert/strict');
const {normalize,world,trajectory,frame}=require('../dist/match3d/scene-adapter.js');
const raw={key:42,kind:'carry',stage:'Course',ball:{x:60,y:29},origin:{x:42,y:35},
 players:Array.from({length:30},(_,i)=>({id:'p'+i,side:i<15?0:1,slot:i%15,x:20+i*2,y:10+i%10,featured:i===3}))};
const freeze=o=>{if(o&&typeof o==='object'){Object.freeze(o);Object.values(o).forEach(freeze)}return o};
freeze(raw);const result=normalize(raw);
assert.equal(result.players.length,30);assert.deepEqual(result.ball,{x:60,y:29});
assert.deepEqual(world({x:50,y:35}),{x:0,z:0});
assert.deepEqual(trajectory({x:0,y:0},{x:100,y:70},.5),{x:50,y:35});
assert.equal(frame(result,result,.4).players.length,30);
assert.equal(raw.players[0].x,20);
assert.equal(result.players[3].featured,true);
assert.equal(normalize({...raw,players:raw.players.concat(raw.players)}).players.length,30);
assert.deepEqual(normalize({...raw,ball:{x:500,y:-2}}).ball,{x:100,y:0});
assert.throws(()=>normalize({}),/indisponible/);
const keyed={...raw,key:{min:1,text:'Passe',scene:{kind:'carry',to:{x:40,y:35}}}};
assert.notEqual(normalize(keyed).key,normalize({...keyed,key:{...keyed.key,min:2}}).key);
console.log('MATCH 3D adapter: 10 assertions OK');
