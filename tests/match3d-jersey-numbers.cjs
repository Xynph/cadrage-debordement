'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {appearance,jerseyDigits,build}=require('../dist/match3d/player-model.js');
assert.equal(jerseyDigits(1).length,1);
assert.equal(jerseyDigits(10).length,2);
assert.equal(jerseyDigits(15).length,2);
assert.equal(jerseyDigits(1)[0],'bc');
assert.equal(jerseyDigits(8)[0].length,7);
assert.deepEqual(jerseyDigits(10),jerseyDigits(10));
assert.equal(jerseyDigits(-10)[0],'bc');
assert.equal(appearance({side:1,slot:14}).number,15);
class Object3D {
 constructor(){
  this.children=[];this.userData={};this.position={set(...v){this.values=v}};
  this.rotation={};this.scale={set(...v){this.values=v}};
 }
 add(x){this.children.push(x)}
}
class Mesh extends Object3D {constructor(geometry,material){super();this.geometry=geometry;this.material=material;}}
class Geometry {constructor(...args){this.args=args;}}
const T={Group:Object3D,Mesh,MeshStandardMaterial:Geometry,MeshBasicMaterial:Geometry,CylinderGeometry:Geometry,
 SphereGeometry:Geometry,BoxGeometry:Geometry,CircleGeometry:Geometry};
for(let side=0;side<2;side++)for(let slot=0;slot<15;slot++){
 const player=Object.freeze({side,slot});
 const model=build(T,player);
 const mark=model.userData.jerseyNumber;
 assert.ok(mark,'numéro absent');
 assert.equal(mark.children.length,slot>=9?2:1);
 assert.ok(mark.children.every(d=>d.children.length>=2&&d.children.length<=7));
 assert.equal(model.userData.motionParts.legs.length,2);
 assert.deepEqual(player,{side,slot});
}
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
assert.ok(html.includes('match3d/player-model.js'));
const main=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
assert.ok(main.includes('model.build(T,p)'));
console.log('MATCH 3D lot 10: numéros de maillot 1-15 validés sur 30 modèles, moteur inchangé');
