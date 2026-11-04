'use strict';
/* Offline glTF skinned athlete adapter. Cesium model © 2017, CC BY 4.0. */
(function(root){
 let model=null,animation=null,pending=null,failed=false;
 const kits=new Map();
 let kitGeometry=null;
 function geometry(T){
  if(!kitGeometry)kitGeometry={torso:new T.CylinderGeometry(.22,.18,.49,8,1),shorts:new T.CylinderGeometry(.185,.19,.22,8),stripe:new T.CylinderGeometry(.224,.224,.055,8)};
  return kitGeometry;
 }
 function kit(T,side){
  const key=side===1?'away':'home';if(kits.has(key))return kits.get(key);
  const palette=side===1?{shirt:0x1886cf,shorts:0x14283c,socks:0xf1f5f9,trim:0xf8f9fb}:{shirt:0xe87932,shorts:0x242e39,socks:0x263444,trim:0xf6e8d0};
  const mats=Object.fromEntries(Object.entries(palette).map(([k,v])=>[k,new T.MeshStandardMaterial({color:v,roughness:.83,metalness:0})]));
  kits.set(key,mats);return mats;
 }
 function uniform(T,clone,player){
  // Lightweight, locally generated kit: no external textures or draw-call-heavy skin overlays.
  const m=kit(T,player&&player.side),g=geometry(T),torso=new T.Mesh(g.torso,m.shirt);
  torso.position.y=.98;clone.add(torso);
  const shorts=new T.Mesh(g.shorts,m.shorts);shorts.position.y=.64;clone.add(shorts);
  const stripe=new T.Mesh(g.stripe,m.trim);stripe.position.y=1.09;clone.add(stripe);
  return {torso,shorts,stripe};
 }

 // Rugby-specific silhouette: equipment follows the animated glTF bones,
 // rather than floating on the world-space character root.
 let equipmentGeometry=null;
 function gearGeometry(T){
  if(!equipmentGeometry)equipmentGeometry={
   shoulder:new T.SphereGeometry(.14,10,8),
   sleeve:new T.CylinderGeometry(.105,.125,.23,10),
   sock:new T.CylinderGeometry(.082,.075,.3,10),
   boot:new T.BoxGeometry(.23,.11,.36),
   collar:new T.TorusGeometry(.14,.025,6,12),
   wrist:new T.CylinderGeometry(.065,.065,.065,8)
  };
  return equipmentGeometry;
 }
 function attachRugbyGear(T,clone,player){
  // All geometry and materials are shared; no network requests or textures.
  const g=gearGeometry(T),m=kit(T,player&&player.side),bones=new Map();
  clone.traverse(o=>{if(o.isBone&&o.name)bones.set(o.name,o);});
  if(!bones.size)return 0;
  const items=[
   ['Skeleton_arm_joint_R',g.shoulder,m.shirt,[-.02,0,0]],
   ['Skeleton_arm_joint_L__4_',g.shoulder,m.shirt,[.02,0,0]],
   ['Skeleton_arm_joint_R__2_',g.sleeve,m.shirt,[0,-.10,0]],
   ['Skeleton_arm_joint_L__3_',g.sleeve,m.shirt,[0,-.10,0]],
   ['leg_joint_R_3',g.sock,m.socks,[0,-.13,0]],
   ['leg_joint_L_3',g.sock,m.socks,[0,-.13,0]],
   ['leg_joint_R_5',g.boot,m.shorts,[0,-.05,.08]],
   ['leg_joint_L_5',g.boot,m.shorts,[0,-.05,.08]],
   ['Skeleton_arm_joint_R__3_',g.wrist,m.trim,[0,0,0]],
   ['Skeleton_arm_joint_L__2_',g.wrist,m.trim,[0,0,0]],
   ['Skeleton_neck_joint_1',g.collar,m.trim,[0,.03,0]]
  ];
  let count=0;
  for(const [boneName,geo,mat,pos] of items){
   const bone=bones.get(boneName);if(!bone)continue;
   const mesh=new T.Mesh(geo,mat);
   mesh.position.set(pos[0],pos[1],pos[2]);
   if(boneName==='Skeleton_neck_joint_1')mesh.rotation.x=Math.PI/2;
   bone.add(mesh);count++;
  }
  return count;
 }
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
   // Per-instance geometry prevents scene disposal from invalidating the template.
   to.geometry=from.geometry.clone();
  }
  clone.scale.setScalar(1.8);
  uniform(T,clone,player);
  const rugbyEquipment=attachRugbyGear(T,clone,player);
  const jersey=player&&player.side===1?0x4cafe4:0xe87932;
  clone.traverse(o=>{
   if(!o.isMesh)return;
   if(o.material){
    o.material=Array.isArray(o.material)?o.material.map(m=>m.clone()):o.material.clone();
    const tint=m=>{if(m.color)m.color.setHex(jersey);};
    if(Array.isArray(o.material))o.material.forEach(tint);else tint(o.material);
   }
  });
  const group=new T.Group();group.add(clone);
  const mixer=new T.AnimationMixer(clone);mixer.clipAction(animation).play();
  group.userData.gltfAthleteV20=true;group.userData.gltfAthleteV21=true;group.userData.gltfAthleteV22=true;group.userData.rugbyEquipment=rugbyEquipment;group.userData.mixer=mixer;
  return group;
 }
 root.CDMatch3DAssetPlayer=Object.freeze({
  load,build,
  tick:(group,delta,pace=1)=>{if(group?.userData.mixer)group.userData.mixer.update(Math.max(0,Math.min(.05,delta))*Math.max(.65,Math.min(1.6,pace)));},
  status:()=>({ready:!!model,failed,loading:!!pending&&!model&&!failed,kits:kits.size})
 });
})(typeof window!=='undefined'?window:globalThis);
