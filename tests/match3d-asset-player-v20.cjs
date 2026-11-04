'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../dist');
const read=p=>fs.readFileSync(path.join(root,p));
test('v20: bundled offline glTF has skin, animation and local buffer',()=>{
 const json=JSON.parse(read('match3d/assets/cesium-athlete.gltf').toString());
 assert.equal(json.asset.version,'2.0');
 assert.ok(json.skins.length>=1);
 assert.ok(json.animations.length>=1);
 assert.ok(json.meshes.length>=1);
 assert.ok(json.buffers.every(b=>b.uri&&!/^https?:/i.test(b.uri)&&read('match3d/assets/'+b.uri).length>=b.byteLength));
 assert.ok(!json.images||json.images.length===0);
});
test('v20: local loader and athlete scripts precede renderer',()=>{
 const html=read('index.html').toString();
 for(const name of ['match3d/vendor/GLTFLoader-r149.js','match3d/asset-player.js','match3d/match3d.js'])
  assert.ok(html.includes(name),name);
 assert.ok(html.indexOf('match3d/asset-player.js')<html.indexOf('match3d/match3d.js'));
 const js=read('match3d/match3d.js').toString();
 assert.match(js,/asset\.load\(T\)/);
 assert.match(js,/model\.build\(T,p\)/);
 assert.match(js,/diagnostics:/);
});

test('v20: loader source is bundled and uses no remote URLs',()=>{
 const loader=read('match3d/vendor/GLTFLoader-r149.js').toString();
 const athlete=read('match3d/asset-player.js').toString();
 assert.match(loader,/THREE\.GLTFLoader = GLTFLoader/);
 assert.doesNotMatch(loader,/^\s*import\s/m);
 assert.match(athlete,/CesiumMan_data|cesium-athlete\.gltf/);
 assert.doesNotMatch(athlete,/https?:\/\//i);
});

test('v20: 30 rigged instances own independent skinned geometry and animate',async()=>{
 const vm=require('node:vm');
 const source=read('match3d/asset-player.js').toString();
 const mesh=()=>({
  isMesh:true,isSkinnedMesh:true,
  geometry:{clone:()=>({independent:true})},
  material:{clone:()=>({color:{setHex(){}}})},
  skeleton:{bones:[],boneInverses:[]},
  bindMatrix:{clone:()=>({})},
  bind(s){this.skeleton=s;}
 });
 const template={
  traverse(fn){fn(this);fn(mesh());},
  clone(){const m=mesh();return {
   scale:{setScalar(){}},
   traverse(fn){fn(this);fn(m);},
   mesh:m
  };}
 };
 class Loader{load(_url,ok){ok({scene:template,animations:[{name:'walking'}]});}}
 class Group{constructor(){this.userData={};}add(node){this.node=node;}}
 class Mixer{constructor(){this.time=0;}clipAction(){return {play(){}};}update(dt){this.time+=dt;}}
 class Skeleton{constructor(bones,inverses){this.bones=bones;this.boneInverses=inverses;}}
 const window={};
 vm.runInNewContext(source,{window,Promise});
 const adapter=window.CDMatch3DAssetPlayer;
 assert.equal(await adapter.load({GLTFLoader:Loader}),true);
 class Mesh{constructor(geometry,material){this.geometry=geometry;this.material=material;this.position={y:0};}}
 class CylinderGeometry{constructor(...args){this.args=args;}}
 class MeshStandardMaterial{constructor(opts){this.color=opts.color;}}
 const T={GLTFLoader:Loader,Group,AnimationMixer:Mixer,Skeleton,Mesh,CylinderGeometry,MeshStandardMaterial};
 const players=Array.from({length:30},(_,i)=>adapter.build(T,{side:i%2}));
 assert.equal(players.filter(p=>p.userData.gltfAthleteV20&&p.userData.gltfAthleteV21).length,30);
 assert.ok(players.every(p=>p.node.uniforms.length===3));
 assert.equal(adapter.status().kits,2);
 assert.equal(new Set(players.map(p=>p.node.mesh.geometry)).size,30);
 for(const p of players)adapter.tick(p,.025);
 assert.ok(players.every(p=>p.userData.mixer.time>.02));
});
test('v20: no loader preserves procedural fallback',async()=>{
 const vm=require('node:vm'),window={};
 vm.runInNewContext(read('match3d/asset-player.js').toString(),{window,Promise});
 const adapter=window.CDMatch3DAssetPlayer;
 assert.equal(await adapter.load({}),false);
 assert.equal(adapter.build({},{}),null);
});
