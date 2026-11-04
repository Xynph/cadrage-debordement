'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const model=require('../dist/match3d/player-model.js');
const motion=require('../dist/match3d/premium-motion.js');
const modelSource=fs.readFileSync(path.join(__dirname,'../dist/match3d/player-model.js'),'utf8');
const sceneSource=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
assert.match(modelSource,/broadcastDetails=true/);
assert.match(modelSource,/Broadcast-readable design details/);
assert.match(modelSource,/Laces and sole/);
assert.match(sceneSource,/CDMatch3DPlayerModel/);
assert.match(sceneSource,/motion\.pose/);
const first=model.appearance({side:0,slot:0});
const opposite=model.appearance({side:1,slot:0});
assert.notEqual(first.shirt,opposite.shirt);
assert.deepEqual(first,model.appearance({side:0,slot:0}));
assert.equal(model.jerseyDigits(15).length,2);
class Obj{
 constructor(){this.children=[];this.userData={};this.position={set(){}};this.rotation={};this.scale={set(){}};}
 add(o){this.children.push(o);}
}
class Geo{constructor(...v){this.args=v;}}
class Mat{constructor(v){Object.assign(this,v);}}
class Mesh extends Obj{constructor(geo,mat){super();this.geometry=geo;this.material=mat;}}
const T={Group:Obj,Mesh,BoxGeometry:Geo,SphereGeometry:Geo,CylinderGeometry:Geo,CircleGeometry:Geo,
 MeshStandardMaterial:Mat,MeshBasicMaterial:Mat};
for(let side=0;side<2;side++)for(let slot=0;slot<15;slot++){
 const rig=model.build(T,{side,slot,featured:slot===0});
 assert.equal(rig.userData.premiumAthleteRig,true);
 assert.equal(rig.userData.broadcastDetails,true);
 assert.equal(rig.userData.motionParts.legs.length,2);
 assert.equal(rig.userData.motionParts.arms.length,2);
 assert.ok(rig.children.length>=20);
}
const still={x:1,y:1},moving={x:8,y:5};
const neutral=motion.pose(still,still,.5,200,0);
const sprint=motion.pose(still,moving,.5,200,0);
assert.equal(neutral.stride,0);
assert.ok(sprint.pace>0);
assert.ok(Number.isFinite(sprint.bounce));
assert.ok(sprint.kneeBend.every(v=>v>=0&&v<=.84));
assert.ok(sprint.elbowFlex.every(v=>v>=.14&&v<=.60));
for(const progress of [-100,0,.25,.5,.75,1,100]){
 const pose=motion.pose(still,moving,progress,1234,6);
 assert.ok(Object.values(pose).flat().every(Number.isFinite));
 assert.ok(Math.abs(pose.hipSway)<=.085);
}
assert.equal(motion.pose(still,moving,0,200,0).stride,0);
assert.equal(motion.pose(still,moving,1,200,0).stride,0);
console.log('MATCH 3D Premium lot 17: 30 rigs and animation bounds OK');
