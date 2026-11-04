'use strict';
const assert=require('node:assert/strict');
const {stunt,pose,plan}=require('../dist/match3d/contact-animation.js');
const fs=require('node:fs'),path=require('node:path');
const zero={lift:0,tuck:0,shoulder:0,recovery:0,footPlant:0};
const pair={lead:'a',other:'b',kind:'turnover',distance:3};
for(const id of ['a','b','outsider'])for(const ms of [-1,0,100,220,340,450,600,720,800,950]){
 const v=stunt(pair,id,ms);
 assert.ok(Object.isFrozen(v));
 assert.ok(Object.values(v).every(Number.isFinite));
 assert.ok(v.lift>=0&&v.lift<=.5);
 assert.ok(v.tuck>=0&&v.tuck<=.95);
 assert.ok(v.shoulder>=0&&v.shoulder<=.5);
 assert.ok(v.recovery>=0&&v.recovery<=1);
 assert.ok(v.footPlant>=0&&v.footPlant<=1);
}
assert.deepEqual(stunt(null,'b',440),zero);
assert.deepEqual(stunt(pair,'other',440),zero);
assert.deepEqual(stunt(pair,'b',NaN),zero);
assert.deepEqual(stunt(pair,'b',800),zero);
assert.deepEqual(stunt(pair,'b',-1),zero);
assert.ok(stunt(pair,'b',420).tuck>stunt(pair,'b',120).tuck);
assert.ok(stunt(pair,'b',520).shoulder>0);
assert.ok(stunt(pair,'b',520).lift>0);
assert.ok(stunt(pair,'b',680).recovery>0);
assert.ok(stunt(pair,'b',680).footPlant>=0);
assert.ok(stunt(pair,'a',430).tuck<stunt(pair,'b',430).tuck);
const carry={lead:'a',other:'b',kind:'carry',distance:3};
assert.equal(stunt(carry,'b',440).recovery,0);
assert.ok(stunt(carry,'b',320).tuck<.15);
assert.ok(stunt(carry,'a',330).shoulder>0);
const scene=Object.freeze({kind:'turnover',possession:0,
 ball:Object.freeze({x:50,y:35}),players:Object.freeze([
  Object.freeze({id:'a',side:0,x:50,y:35,featured:true}),
  Object.freeze({id:'b',side:1,x:53,y:36})])});
const before=JSON.stringify(scene),detected=plan(scene);
assert.ok(detected);
assert.ok(stunt(detected,'b',450).tuck>0);
assert.equal(pose(detected,'b',800).fall,0);
assert.equal(JSON.stringify(scene),before);
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
assert.ok(renderer.includes('contact.stunt(instance.contact,p.id,elapsed)'));
assert.ok(renderer.includes('pose.bounce+stumble.lift'));
assert.ok(renderer.includes('stumble.tuck*.85'));
assert.ok(renderer.includes('stumble.recovery*.12'));
console.log('MATCH 3D lot 14 : transitions déséquilibre/sol/roulade/relevé vérifiées');
