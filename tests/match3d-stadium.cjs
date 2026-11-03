'use strict';
const assert=require('node:assert/strict');
const {layout,build}=require('../dist/match3d/stadium-atmosphere.js');
const sections=layout();
assert.equal(sections.length,3);
assert.ok(Object.isFrozen(sections));
assert.ok(sections.every(x=>Object.isFrozen(x)&&x.radius>0&&x.width>0&&x.height>0));
const created=[];
class Mesh {constructor(geometry,material){this.geometry=geometry;this.material=material;this.rotation={};this.position={set(...x){this.coords=x;}};}}
class PointLight {constructor(){this.position={set(...x){this.coords=x;}};}}
const T={Mesh,RingGeometry:class{},CylinderGeometry:class{},MeshStandardMaterial:class{},PointLight,DoubleSide:2};
const scene={add(x){created.push(x);}};
const built=build(scene,T);
assert.equal(built.bands.length,3);
assert.equal(built.lamps.length,4);
assert.equal(created.length,11);
assert.ok(Object.isFrozen(built));
assert.throws(()=>build(null,T),/scene required/);
console.log('MATCH 3D premium stadium layout: OK');
