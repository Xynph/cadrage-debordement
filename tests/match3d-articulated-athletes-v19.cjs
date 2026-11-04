'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const model=require('../dist/match3d/player-model.js');
const motion=require('../dist/match3d/premium-motion.js');
const scene=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
class Obj {
 constructor(){this.children=[];this.userData={};this.position={set(){}};this.rotation={};this.scale={set(){}};}
 add(x){this.children.push(x);}
}
class Geo {constructor(...args){this.args=args;}}
class Mat {constructor(values){Object.assign(this,values);}}
class Mesh extends Obj {constructor(geo,mat){super();this.geometry=geo;this.material=mat;}}
const T={Group:Obj,Mesh,BoxGeometry:Geo,SphereGeometry:Geo,CylinderGeometry:Geo,CircleGeometry:Geo,
 MeshStandardMaterial:Mat,MeshBasicMaterial:Mat};
let rigs=0;
for(let side=0;side<2;side++)for(let slot=0;slot<15;slot++){
 const rig=model.build(T,{side,slot,featured:slot===0});
 const parts=rig.userData.motionParts;
 assert.equal(rig.userData.articulatedAthleteV19,true);
 assert.equal(parts.headRig.children.length>=5,true);
 assert.equal(parts.wrists.length,2);
 assert.equal(parts.ankles.length,2);
 assert.equal(parts.legs.length,2);
 assert.equal(parts.knees.length,2);
 assert.equal(parts.elbows.length,2);
 for(const wrist of parts.wrists)assert.ok(wrist.children.length>=2);
 for(const ankle of parts.ankles)assert.ok(ankle.children.length>=5);
 rigs++;
}
assert.equal(rigs,30);
for(const progress of [-2,0,.1,.4,.5,.8,1,3]){
 const p=motion.pose({x:0,y:0},{x:8,y:6},progress,830,4);
 assert.ok(p.footRoll.every(v=>Number.isFinite(v)&&Math.abs(v)<=.23));
 assert.ok(p.wristFlex.every(v=>Number.isFinite(v)&&Math.abs(v)<=.18));
 assert.ok(Number.isFinite(p.headTurn)&&Math.abs(p.headTurn)<=.1);
 assert.ok(Number.isFinite(p.headNod)&&p.headNod>=0&&p.headNod<=.075);
 if(progress<=0||progress>=1){
  assert.ok(p.footRoll.every(v=>v===0));
  assert.ok(p.wristFlex.every(v=>v===0));
  assert.ok(p.headTurn===0);
 }
}
const still=motion.pose({x:1,y:1},{x:1,y:1},.5,800,3);
assert.ok(still.footRoll.every(v=>v===0));
assert.ok(still.wristFlex.every(v=>v===0));
assert.ok(still.headTurn===0);
assert.match(scene,/parts\.headRig\.rotation\.y=pose\.headTurn/);
assert.match(scene,/parts\.wrists\[0\]\.rotation\.x=pose\.wristFlex\[0\]/);
assert.match(scene,/parts\.ankles\[0\]\.rotation\.x=pose\.footRoll\[0\]/);
console.log('MATCH 3D lot 19: 30 articulated rigs, foot/wrist/head motion, bounds OK');
