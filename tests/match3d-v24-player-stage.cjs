'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const THREE=require('../dist/match3d/vendor/three-r149.min.js');
const sandbox={};vm.runInNewContext(fs.readFileSync('dist/match3d/assets/rugby-v24/player-stage.js','utf8'),sandbox);
const api=sandbox.CDMatch3DV24Stage;
assert.equal(api.chooseLOD(10),0);
assert.equal(api.chooseLOD(20),1);
assert.equal(api.chooseLOD(55),2);
assert.equal(api.chooseLOD(16,0),0,'Hysteresis anti-oscillation');
assert.equal(api.chooseLOD(18,0),1);
assert.equal(api.chooseLOD(36,2),2);
assert.throws(()=>api.chooseLOD(NaN),/invalide/);
function fixture(lod){
 const root=new THREE.Group(),bones=Array.from({length:53},(_,i)=>{const b=new THREE.Bone();b.name='bone'+i;return b;});
 root.add(bones[0]);for(let i=1;i<53;i++)bones[i-1].add(bones[i]);
 const skeleton=new THREE.Skeleton(bones);
 for(let i=0;i<4;i++){
  const geometry=new THREE.BufferGeometry();
  geometry.setAttribute('position',new THREE.Float32BufferAttribute([0,0,0,1,0,0,0,1,0],3));
  geometry.setAttribute('skinIndex',new THREE.Uint16BufferAttribute([0,0,0,0,0,0,0,0,0,0,0,0],4));
  geometry.setAttribute('skinWeight',new THREE.Float32BufferAttribute([1,0,0,0,1,0,0,0,1,0,0,0],4));
  geometry.setIndex([0,1,2]);
  const m=new THREE.SkinnedMesh(geometry,new THREE.MeshStandardMaterial({color:0xffffff}));
  m.name=['Body','Cloth_tshirt','Cloth_shorts','Cloth_shoes'][i];
  root.add(m);m.bind(skeleton);
 }
 return {body:root,bones,clips:[new THREE.AnimationClip('idle',1,[])],lod};
}
const assets=[fixture(0),fixture(1),fixture(2)];
const players=Array.from({length:30},(_,i)=>({id:'player'+i,side:i<15?0:1,x:i<10?5:i<20?24:55,z:0}));
const built=api.stage(THREE,assets,players,{x:0,z:0});
assert.equal(built.length,30);
assert.deepEqual(Array.from(built,m=>m.lod).filter(x=>x===0).length,10);
assert.deepEqual(Array.from(built,m=>m.lod).filter(x=>x===1).length,10);
assert.deepEqual(Array.from(built,m=>m.lod).filter(x=>x===2).length,10);
for(const m of built){assert.equal(m.meshes,4);assert.equal(m.bones.length,53);assert.equal(m.clips.length,1);}
assert.equal(new Set(built.map(m=>m.bones[0])).size,30,'No shared root bone');
assert.equal(new Set(built.map(m=>m.mixer)).size,30,'No shared mixer');
const player0=built[0],player1=built[1];
player0.bones[0].rotation.x=.5;
assert.ok(Math.abs(player1.bones[0].rotation.x)<1e-9,'Independent pose (-0 is equivalent to +0)');
assert.ok(Math.abs(assets[0].bones[0].rotation.x)<1e-9,'Asset template untouched');
const materials=built.map(x=>{const ms=[];x.body.traverse(n=>{if(n.isSkinnedMesh&&n.name==='Cloth_tshirt')ms.push(n.material)});return ms[0];});
assert.equal(new Set(materials).size,30,'Materials independent');
assert.notEqual(materials[0].color.getHex(),materials[20].color.getHex(),'Two distinct kits');
assert.throws(()=>api.stage(THREE,assets,players.slice(0,29),{x:0,z:0}),/30/);
assert.throws(()=>api.stage(THREE,assets.slice(0,2),players,{x:0,z:0}),/3 LOD/);
console.log('PASS 30 offline v24 staged rigs, 3 LOD, independent skeletons/mixers/kits, validation and fallback gate');
