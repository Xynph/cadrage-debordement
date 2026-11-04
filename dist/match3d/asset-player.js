'use strict';
/* Offline glTF skinned athlete adapter. Cesium model © 2017, CC BY 4.0. */
(function(root){
 let model=null,animation=null,pending=null,failed=false;
 function load(T){
  if(pending)return pending;
  if(!T||!T.GLTFLoader){failed=true;return Promise.resolve(false);}
  pending=new Promise(resolve=>{
   new T.GLTFLoader().load('match3d/assets/cesium-athlete.gltf',gltf=>{
    let skins=0;gltf.scene.traverse(o=>{if(o.isSkinnedMesh)skins++;});
    if(!skins||!gltf.animations.length){failed=true;resolve(false);return;}
    model=gltf.scene;animation=gltf.animations[0];resolve(true);
   },undefined,()=>{failed=true;resolve(false);});
  });
  return pending;
 }
 function build(T,player){
  if(!model)return null;
  const clone=model.clone(true),original=[],copied=[];
  model.traverse(o=>original.push(o));clone.traverse(o=>copied.push(o));
  const nodes=new Map(original.map((o,i)=>[o,copied[i]]));
  for(let i=0;i<original.length;i++)if(original[i].isSkinnedMesh){
   const from=original[i],to=copied[i];
   to.skeleton=new T.Skeleton(from.skeleton.bones.map(b=>nodes.get(b)),from.skeleton.boneInverses.map(m=>m.clone()));
   to.bind(to.skeleton,from.bindMatrix.clone());
  }
  clone.scale.setScalar(1.8);
  const group=new T.Group();group.add(clone);
  const mixer=new T.AnimationMixer(clone);mixer.clipAction(animation).play();
  group.userData.gltfAthleteV20=true;group.userData.mixer=mixer;
  return group;
 }
 root.CDMatch3DAssetPlayer=Object.freeze({
  load,build,
  tick:(group,delta)=>{if(group?.userData.mixer)group.userData.mixer.update(Math.max(0,Math.min(.05,delta)));},
  status:()=>({ready:!!model,failed,loading:!!pending&&!model&&!failed})
 });
})(typeof window!=='undefined'?window:globalThis);
