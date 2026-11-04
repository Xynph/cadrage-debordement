'use strict';
const assert=require('node:assert/strict');
const {build}=require('../dist/match3d/player-model.js');
const {pose}=require('../dist/match3d/premium-motion.js');
class Object3D{
 constructor(){this.children=[];this.userData={};this.position={set(...v){this.values=v}};this.rotation={};this.scale={set(...v){this.values=v}};}
 add(o){this.children.push(o);}
}
class Mesh extends Object3D{constructor(geometry,material){super();this.geometry=geometry;this.material=material;}}
class Geom{constructor(...args){this.args=args;}}
const T={Group:Object3D,Mesh,MeshStandardMaterial:Geom,MeshBasicMaterial:Geom,
 CylinderGeometry:Geom,SphereGeometry:Geom,BoxGeometry:Geom,CircleGeometry:Geom};
for(let side=0;side<2;side++)for(let slot=0;slot<15;slot++){
 const model=build(T,{side,slot,featured:slot===0});
 const rig=model.userData.motionParts;
 assert.equal(model.userData.premiumAthleteRig,true);
 assert.equal(rig.elbows.length,2);
 assert.equal(rig.knees.length,2);
 assert.equal(rig.arms.length,2);
 assert.equal(rig.legs.length,2);
 assert.ok(rig.elbows.every(e=>e.children.length>=3));
 assert.ok(rig.elbows.every(e=>rig.arms.some(a=>a.children.includes(e))));
 assert.ok(rig.knees.every(k=>rig.legs.some(l=>l.children.includes(k))));
 assert.ok(model.userData.jerseyNumber.children.length>=1);
}
const before=Object.freeze({x:0,y:0}),next=Object.freeze({x:9,y:0});
const moving=pose(before,next,.5,160,3);
const idle=pose(before,before,.5,160,3);
assert.equal(moving.elbowFlex.length,2);
assert.ok(moving.elbowFlex.every(a=>a>=.14&&a<=.60));
assert.ok(moving.landing>=0&&moving.landing<=1);
assert.ok(Math.abs(moving.hipSway)<=.06);
assert.deepEqual(idle.elbowFlex,[.14,.14]);
assert.ok(Math.abs(idle.hipSway)<1e-12);
assert.deepEqual(pose(before,next,.5,160,3),moving);
assert.deepEqual(before,{x:0,y:0});
const fs=require('node:fs'),path=require('node:path');
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
assert.ok(renderer.includes('parts.elbows[0].rotation.x'));
assert.ok(renderer.includes('pose.elbowFlex[0]'));
assert.ok(renderer.includes('parts.torso.rotation.z=pose.hipSway'));
console.log('MATCH 3D lot 13 : 30 rigs articulés et animation de course validés');
