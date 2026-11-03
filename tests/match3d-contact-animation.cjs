'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {plan,pose}=require('../dist/match3d/contact-animation.js');
const src=Object.freeze({
 kind:'turnover',key:'scene-42',possession:0,ball:Object.freeze({x:50,y:35}),
 players:Object.freeze([
  Object.freeze({id:'attacker',side:0,x:50,y:35,featured:true}),
  Object.freeze({id:'near',side:1,x:53,y:37}),
  Object.freeze({id:'far',side:1,x:83,y:62}),
  Object.freeze({id:'reserve',side:0,x:34,y:40})
 ])
});
const choice=plan(src);
assert.equal(choice.lead,'attacker');
assert.equal(choice.other,'near');
assert.equal(choice.kind,'turnover');
assert.ok(choice.distance>0&&choice.distance<=9);
assert.deepEqual(choice,plan(src));
assert.equal(plan({...src,kind:'try'}),null);
assert.equal(plan({...src,players:src.players.filter(p=>p.side===0)}),null);
assert.equal(plan({...src,players:src.players.filter(p=>p.id!=='near')}),null);
assert.equal(plan({...src,kind:'carry'}).kind,'carry');
assert.equal(plan({...src,kind:'carry'}).distance,choice.distance);
assert.deepEqual(pose(choice,'far',450),{lean:0,roll:0,fall:0,bracing:0});
assert.equal(pose(choice,'near',0).fall,0);
const middle=pose(choice,'near',440);
assert.ok(middle.fall>0&&middle.fall<=1.1);
assert.ok(middle.bracing>=0&&middle.bracing<=1);
assert.ok(Number.isFinite(middle.roll));
assert.equal(pose(choice,'near',800).fall,0);
assert.deepEqual(pose(choice,'near',10000),pose(choice,'near',800));
assert.equal(pose({...choice,kind:'carry'},'near',440).fall,0);
assert.ok(pose(choice,'attacker',440).fall===0);
assert.ok(pose(choice,'attacker',440).bracing>0);
assert.equal(plan({...src,players:[{id:'bad',side:0,x:NaN,y:1},...src.players]}).lead,'attacker');
assert.equal(plan({...src,ball:{x:NaN,y:NaN}})?.lead,'attacker');
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
assert.ok(html.indexOf('match3d/contact-animation.js')>html.indexOf('match3d/player-model.js'));
assert.ok(html.indexOf('match3d/contact-animation.js')<html.indexOf('match3d/match3d.js'));
assert.equal((html.match(/match3d\/contact-animation\.js/g)||[]).length,1);
assert.ok(renderer.includes('contact.plan(next)'));
assert.ok(renderer.includes('contact.pose(instance.contact,p.id,now-instance.start)'));
assert.ok(renderer.includes('object.rotation.x=cue.fall'));
assert.ok(renderer.includes('object.rotation.z=cue.roll'));
assert.deepEqual(src.players[0],{id:'attacker',side:0,x:50,y:35,featured:true});
console.log('MATCH 3D contact lot 08: 29 assertions OK');
