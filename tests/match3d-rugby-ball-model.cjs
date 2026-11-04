'use strict';
const assert=require('node:assert/strict');
const model=require('../dist/match3d/rugby-ball-model.js');
assert.ok(Object.isFrozen(model.detail));
assert.equal(model.detail.laceCount,5);
const objects=[];
class Group{
 constructor(){this.children=[];this.userData={};this.position={set(...v){this.values=v}};this.rotation={};this.scale={set(...v){this.values=v}};}
 add(o){this.children.push(o);}
}
class Mesh extends Group{constructor(geometry,material){super();this.geometry=geometry;this.material=material;objects.push(this);}}
class Line extends Mesh{}
class Geometry{constructor(...args){this.args=args;}setFromPoints(points){this.points=points;return this;}}
class Material{constructor(options){this.options=options;}}
class Vector3{constructor(x,y,z){Object.assign(this,{x,y,z});}}
const T={Group,Mesh,Line,Vector3,
 SphereGeometry:Geometry,TorusGeometry:Geometry,BoxGeometry:Geometry,
 BufferGeometry:Geometry,MeshStandardMaterial:Material,LineBasicMaterial:Material};
const a=model.build(T),b=model.build(T);
assert.equal(a.userData.renderOnlyBall,true);
assert.equal(a.children.length,10);
assert.equal(a.children[0].geometry.args[0],1);
assert.deepEqual(a.children[0].scale.values,[.775,.35,.35]);
assert.equal(a.children.filter(x=>x.geometry.args.length===4).length,2);
assert.equal(a.children.filter(x=>x instanceof Line).length,2);
assert.equal(a.children.filter(x=>x.geometry.args.length===3 && x.geometry.args[0]===.025).length,5);
assert.equal(b.children.length,a.children.length);
assert.notEqual(a,b);
assert.ok(objects.every(o=>o.geometry&&o.material));
assert.ok(a.children.filter(x=>x instanceof Line).every(x=>
 x.geometry.points.length===15&&x.geometry.points.every(p=>
 [p.x,p.y,p.z].every(Number.isFinite))));
assert.equal(a.position.values,undefined);
console.log('MATCH 3D lot 12: modèle ballon rugby hors-ligne et sans moteur OK');
