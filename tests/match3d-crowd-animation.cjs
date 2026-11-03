'use strict';
const assert=require('node:assert/strict');
const {plan}=require('../dist/match3d/stadium-crowd.js');
const {isTry,offset,create}=require('../dist/match3d/crowd-animation.js');
assert.equal(isTry({kind:'essai'}),true);
assert.equal(isTry({kind:'try'}),true);
assert.equal(isTry({kind:'penalty'}),false);
assert.equal(isTry({stage:'Essai marqué',kind:'message'}),true);
assert.equal(isTry({stage:'préparation essai',kind:'message'}),false);
assert.equal(isTry(null),false);
for(const t of [-9999,0,200,1e10,NaN])for(const n of [0,1,767]){
 const a=offset(n,t),b=offset(n,t,1);
 assert.ok(Number.isFinite(a)&&Number.isFinite(b));
 assert.ok(a>=-.08&&a<=.65&&b>=-.08&&b<=.65);
}
const seats=plan(8),calls=[];
class Obj{constructor(){this.position={set:(x,y,z)=>calls.push([x,y,z])};this.matrix={};}updateMatrix(){}}
const mesh={instanceMatrix:{needsUpdate:false},setMatrixAt(){}};
const animator=create(mesh,{Object3D:Obj},seats);
assert.equal(animator.tick(100),true);
assert.equal(calls.length,24);
assert.equal(animator.tick(101),false);
animator.event({key:'first',kind:'essai'},200);
assert.equal(animator.tick(200),true);
assert.ok(calls.slice(-24).some((p,i)=>p[1]>seats[i].y+.12));
animator.event({key:'first',kind:'essai'},3000); // same event never retriggers
animator.tick(3000);
assert.ok(calls.slice(-24).every((p,i)=>p[1]<seats[i].y+.12));
animator.dispose();
assert.equal(animator.tick(4000),false);
assert.throws(()=>create(null,{Object3D:Obj},seats),/Instanced crowd required/);
console.log('MATCH 3D crowd celebration and bounded animation: OK');
