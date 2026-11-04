'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const impact=require('../dist/match3d/impact-effects.js');
assert.equal(impact.count,12);
for(let i=0;i<12;i++){
 const p=impact.sample(i,.5);
 assert.ok([p.x,p.y,p.z,p.opacity].every(Number.isFinite));
 assert.ok(p.y>=.04&&p.opacity>0);
}
assert.equal(impact.sample(1,1).opacity,0);
assert.deepEqual(impact.sample(2,.33),impact.sample(2,.33));
const pair=Object.freeze({lead:'a',other:'b',kind:'turnover'});
const players=new Map([['a',{position:{x:4,z:8}}],['b',{position:{x:6,z:10}}]]);
assert.deepEqual(impact.active(pair,430,players),{x:5,z:9,t:.5});
assert.equal(impact.active(pair,100,players),null);
assert.equal(impact.active(pair,900,players),null);
assert.equal(impact.active(null,430,players),null);
assert.equal(impact.active(pair,430,new Map()),null);
assert.equal(impact.active(pair,430,new Map([['a',{position:{x:NaN,z:0}}],['b',{position:{x:0,z:0}}]])),null);
class Obj{
 constructor(){this.children=[];this.visible=true;this.position={set:(...args)=>{this.coords=args}};this.rotation={};this.scale={setScalar:(v)=>{this.scaleValue=v}};}
 add(x){this.children.push(x)}
 remove(x){this.children.splice(this.children.indexOf(x),1)}
}
class Mesh extends Obj{constructor(geometry,material){super();this.geometry=geometry;this.material=material}}
class Geo{dispose(){this.disposed=true}}
class Mat{constructor(data){Object.assign(this,data)}dispose(){this.disposed=true}}
const T={Group:Obj,Mesh,SphereGeometry:Geo,RingGeometry:Geo,MeshBasicMaterial:Mat,DoubleSide:2};
const scene=new Obj(),effect=impact.create(scene,T);
assert.equal(scene.children.length,1);
assert.equal(effect.group.visible,false);
assert.equal(effect.group.children.length,13);
effect.tick(pair,430,players);
assert.equal(effect.group.visible,true);
assert.deepEqual(effect.group.coords,[5,0,9]);
assert.ok(effect.group.children.slice(0,12).some(p=>p.visible&&p.coords[1]>0));
effect.tick(null,430,players);
assert.equal(effect.group.visible,false);
effect.tick(pair,751,players);
assert.equal(effect.group.visible,false);
effect.dispose();
assert.equal(scene.children.length,0);
assert.equal(effect.group.children[0].geometry.disposed,true);
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
assert.ok(renderer.includes('impact.create(scene,T)'));
assert.ok(renderer.includes('instance.impactEffects.tick(instance.contact,now-instance.start,instance.players)'));
assert.ok(renderer.includes('i.impactEffects.dispose()'));
assert.equal((html.match(/match3d\\/impact-effects\\.js/g)||[]).length,1);
assert.ok(html.indexOf('match3d/impact-effects.js')>html.indexOf('match3d/contact-animation.js'));
assert.ok(html.indexOf('match3d/impact-effects.js')<html.indexOf('match3d/match3d.js'));
console.log('MATCH 3D lot 09 impact visuel: contrôles Node OK');
