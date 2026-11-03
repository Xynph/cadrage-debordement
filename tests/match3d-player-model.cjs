'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {appearance,build}=require('../dist/match3d/player-model.js');
const {pose}=require('../dist/match3d/premium-motion.js');
assert.equal(appearance({side:0,slot:0}).number,1);
assert.equal(appearance({side:1,slot:14}).number,15);
assert.notEqual(appearance({side:0,slot:4}).shirt,appearance({side:1,slot:4}).shirt);
assert.deepEqual(appearance({side:0,slot:2}),appearance({side:0,slot:2}));
assert.equal(appearance({side:1,slot:-9}).number,1);
const objects=[];
class Object3D{
 constructor(){this.children=[];this.userData={};this.position={set(...v){this.values=v}};this.rotation={};this.scale={set(...v){this.values=v}};}
 add(child){this.children.push(child);}
}
class Mesh extends Object3D{constructor(geometry,material){super();this.geometry=geometry;this.material=material;objects.push(this)}}
const geom=class{constructor(...args){this.args=args}};
const T={Group:Object3D,Mesh,MeshStandardMaterial:geom,MeshBasicMaterial:geom,
 CylinderGeometry:geom,SphereGeometry:geom,BoxGeometry:geom,CircleGeometry:geom};
const model=build(T,{side:0,slot:8,featured:true});
assert.ok(model.children.length>10);
assert.equal(model.userData.motionParts.legs.length,2);
assert.equal(model.userData.motionParts.arms.length,2);
assert.equal(model.userData.motionParts.knees.length,2);
assert.ok(objects.length>=20);
assert.ok(objects.every(m=>m.geometry instanceof geom));
const poseRun=pose({x:0,y:0},{x:9,y:0},.5,120,4);
assert.equal(poseRun.kneeBend.length,2);
assert.ok(poseRun.kneeBend.every(v=>v>=0&&v<=.75));
assert.deepEqual(pose({x:1,y:1},{x:1,y:1},.5,120,4).kneeBend,[0,0]);
assert.ok(Number.isFinite(poseRun.direction));
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
assert.ok(renderer.includes('CDMatch3DPlayerModel'));
assert.ok(renderer.includes('parts.knees[0].rotation.x'));
assert.ok(html.indexOf('match3d/player-model.js')<html.indexOf('match3d/match3d.js'));
assert.equal((html.match(/match3d\/player-model\.js/g)||[]).length,1);
console.log('MATCH 3D lot 07: 17 checks OK');
