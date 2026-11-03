'use strict';
const assert=require('node:assert/strict');
const {plan,build}=require('../dist/match3d/stadium-crowd.js');
const a=plan(),b=plan();
assert.equal(a.length,768);
assert.deepEqual(a,b);
assert.ok(Object.isFrozen(a)&&a.every(p=>Object.isFrozen(p)));
assert.equal(plan(-20).length,24);
assert.equal(plan(100000).length,1152);
assert.equal(plan(NaN).length,768);
assert.ok(a.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z)&&Number.isInteger(p.color)));
class Mesh {
 constructor(g,m,n){this.count=n;this.instanceMatrix={needsUpdate:false};this.instanceColor={needsUpdate:false};this.samples=[];}
 setMatrixAt(i,m){this.samples.push(i);}
 setColorAt(){}
}
class Obj{constructor(){this.position={set(){}};this.matrix={};}updateMatrix(){}}
const T={InstancedMesh:Mesh,Object3D:Obj,SphereGeometry:class{},MeshLambertMaterial:class{},Color:class{}};
const added=[];const mesh=build({add:x=>added.push(x)},T,8);
assert.equal(mesh.count,24);assert.equal(mesh.samples.length,24);
assert.equal(mesh.instanceMatrix.needsUpdate,true);
assert.equal(added.length,1);
assert.throws(()=>build(null,T),/instancing required/);
console.log('MATCH 3D premium procedural crowd: OK');
