'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.resolve(__dirname,'../dist/match3d/asset-player.js'),'utf8');

test('v22: 30 local animated rugby players have bone-bound equipment and two team kits',async()=>{
 const names=['Skeleton_arm_joint_R','Skeleton_arm_joint_L__4_','Skeleton_arm_joint_R__2_','Skeleton_arm_joint_L__3_','leg_joint_R_3','leg_joint_L_3','leg_joint_R_5','leg_joint_L_5','Skeleton_arm_joint_R__3_','Skeleton_arm_joint_L__2_','Skeleton_neck_joint_1'];
 const bone=(name)=>({name,isBone:true,children:[],add(m){this.children.push(m);}});
 const mesh=()=>({isMesh:true,isSkinnedMesh:true,geometry:{clone:()=>({})},material:{clone:()=>({color:{setHex(){}}})},skeleton:{bones:[],boneInverses:[]},bindMatrix:{clone:()=>({})},bind(s){this.skeleton=s;}});
 function rig(){
  const bones=names.map(bone),skinned=mesh();
  return {bones,skinned,scale:{setScalar(){}},add(){},traverse(fn){fn(this);fn(skinned);bones.forEach(fn);}};
 }
 const original=rig();
 original.clone=()=>rig();
 class GLTFLoader{load(url,ok){assert.equal(url,'match3d/assets/cesium-athlete.gltf');ok({scene:original,animations:[{name:'motion'}]});}}
 class Group{constructor(){this.userData={};}add(n){this.node=n;}}
 class AnimationMixer{constructor(){this.time=0;}clipAction(){return {play(){}};}update(delta){this.time+=delta;}}
 class Skeleton{constructor(b,i){this.bones=b;this.boneInverses=i;}}
 class Shape{constructor(...args){this.args=args;}}
 class Mesh{constructor(g,m){this.geometry=g;this.material=m;this.position={x:0,y:0,z:0,set(x,y,z){this.x=x;this.y=y;this.z=z;}};this.rotation={x:0};} }
 class Material{constructor(params){this.color=params.color;}}
 const T={GLTFLoader,Group,AnimationMixer,Skeleton,Mesh,MeshStandardMaterial:Material,CylinderGeometry:Shape,SphereGeometry:Shape,BoxGeometry:Shape,TorusGeometry:Shape};
 const context={window:{},Promise};
 vm.runInNewContext(source,context);
 const adapter=context.window.CDMatch3DAssetPlayer;
 assert.equal(await adapter.load(T),true);
 const players=Array.from({length:30},(_,i)=>adapter.build(T,{side:i<15?0:1}));
 assert.equal(players.length,30);
 assert.ok(players.every(p=>p.userData.gltfAthleteV22 && p.userData.rugbyEquipment===11));
 assert.equal(adapter.status().kits,2);
 assert.equal(players[0].node.bones.reduce((n,b)=>n+b.children.length,0),11);
 const left=players[0].node.bones[0].children[0],right=players[1].node.bones[0].children[0];
 assert.equal(left.geometry,right.geometry,'30 rigs share GPU equipment geometry');
 assert.equal(left.material,right.material,'same-side rigs share materials');
 assert.notEqual(left.material,players[20].node.bones[0].children[0].material,'opposing teams use distinct kits');
 players.forEach(p=>adapter.tick(p,.025));
 assert.ok(players.every(p=>p.userData.mixer.time>.02));
});

test('v22: absence of asset loader still enables procedural fallback',async()=>{
 const context={window:{},Promise};vm.runInNewContext(source,context);
 const adapter=context.window.CDMatch3DAssetPlayer;
 assert.equal(await adapter.load({}),false);
 assert.equal(adapter.build({},{}),null);
});

test('v22: equipment assets are offline, with no new remote dependency',()=>{
 assert.doesNotMatch(source,/fetch\s*\(|https?:\/\//);
 assert.match(source,/attachRugbyGear/);
 assert.match(source,/gltfAthleteV22/);
});
