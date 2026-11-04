'use strict';
/* MATCH 3D v22: offline Quaternius Animated Men pack (CC0 1.0).
 * Converted FBX to GLB by kendrekaran/striker-3d, redistribution under CC0.
 * Rendering only. This never changes simulation, players, or saved games. */
(function(root){
 const fallback=root.CDMatch3DAssetPlayer;
 let template=null,clips=[],pending=null,failed=false;
 const palettes=new Map();
 const kitColors={
  home:{Shirt:0xe87932,Shirt2:0xf4cfaa,Pants:0x242e39,Socks:0x263444,Shoes:0x202326},
  away:{Shirt:0x1886cf,Shirt2:0xdceffc,Pants:0x14283c,Socks:0xf1f5f9,Shoes:0x202326}
 };
 function load(T){
  if(pending)return pending;
  if(!T||!T.GLTFLoader){failed=true;return fallback?fallback.load(T).then(()=>false):Promise.resolve(false);}
  pending=new Promise(resolve=>{
   new T.GLTFLoader().load('match3d/assets/quaternius-rugby-athlete.glb',gltf=>{
    let skinned=0;gltf.scene.traverse(o=>{if(o.isSkinnedMesh)skinned++;});
    if(!skinned||!gltf.animations.some(a=>/Man_Run/i.test(a.name||''))){failed=true;resolve(false);return;}
    template=gltf.scene;clips=gltf.animations;resolve(true);
   },undefined,()=>{failed=true;resolve(false);});
  }).then(ok=>{
   if(!ok&&fallback)return fallback.load(T).then(()=>false);
   return ok;
  });
  return pending;
 }
 function build(T,player){
  if(!template)return fallback?fallback.build(T,player):null;
  const clone=template.clone(true),orig=[],copy=[];
  template.traverse(o=>orig.push(o));clone.traverse(o=>copy.push(o));
  const corresponding=new Map(orig.map((o,i)=>[o,copy[i]]));
  const side=player&&player.side===1?'away':'home';
  const color=kitColors[side];
  // Material instances shared per team. Skin, eyes and hair retain source colors.
  if(!palettes.has(side))palettes.set(side,new Map());
  const materialCache=palettes.get(side);
  for(let i=0;i<orig.length;i++){
   const from=orig[i],to=copy[i];
   if(!from.isSkinnedMesh)continue;
   const bones=from.skeleton.bones.map(b=>corresponding.get(b));
   if(bones.some(b=>!b))return fallback?fallback.build(T,player):null;
   to.skeleton=new T.Skeleton(bones,from.skeleton.boneInverses.map(m=>m.clone()));
   to.bind(to.skeleton,from.bindMatrix.clone());
   // Shared immutable skin geometry limits thirty rigs to the original GLB GPU buffers.
   to.geometry=from.geometry;
   to.geometry.userData=to.geometry.userData||{};
   to.geometry.userData.cdMatch3DReusable=true;
   function material(source){
    const key=source.uuid||source.name||'unnamed';
    if(!materialCache.has(key)){
     const m=source.clone(),keyName=source.name||'';
     if(Object.prototype.hasOwnProperty.call(color,keyName)&&m.color)m.color.setHex(color[keyName]);
     m.userData=m.userData||{};m.userData.cdMatch3DReusable=true;
     materialCache.set(key,m);
    }
    return materialCache.get(key);
   }
   to.material=Array.isArray(from.material)?from.material.map(material):material(from.material);
  }
  // Automatic local-size calibration; source FBX->GLB includes a 100x mesh transform.
  if(T.Box3&&T.Vector3){
   const size=new T.Vector3(),bounds=new T.Box3().setFromObject(clone);
   bounds.getSize(size);
   if(Number.isFinite(size.y)&&size.y>.01)clone.scale.multiplyScalar(1.9/size.y);
  }
  const group=new T.Group();group.add(clone);
  const mixer=new T.AnimationMixer(clone);
  const animations={};
  for(const [key,pattern] of [['run',/Man_Run$/i],['walk',/Man_Walk$/i],['idle',/Man_Idle$/i],['fall',/Man_Death$/i],['jump',/Man_Jump$/i]]){
   const clip=clips.find(c=>pattern.test(c.name||''));if(clip)animations[key]=mixer.clipAction(clip);
  }
  const current=animations.run||animations.walk||animations.idle;
  if(current)current.play();
  group.userData.gltfAthleteV20=true;group.userData.gltfAthleteV22=true;
  group.userData.quaterniusAthleteV22=true;
  group.userData.mixer=mixer;group.userData.actions=animations;group.userData.currentAction=current;
  return group;
 }
 function tick(group,delta,pace=1,fall=false){
  if(!group?.userData?.quaterniusAthleteV22){if(fallback)fallback.tick(group,delta,pace);return;}
  const ud=group.userData;
  const selected=fall?(ud.actions.fall||ud.actions.idle):(pace<.8?(ud.actions.walk||ud.actions.run):(ud.actions.run||ud.actions.walk));
  if(selected&&selected!==ud.currentAction){
   selected.reset().play();
   if(ud.currentAction&&ud.currentAction.crossFadeTo)ud.currentAction.crossFadeTo(selected,.22,false);
   ud.currentAction=selected;
  }
  if(selected&&selected.setEffectiveTimeScale)selected.setEffectiveTimeScale(Math.max(.65,Math.min(1.5,pace)));
  ud.mixer.update(Math.max(0,Math.min(.05,delta)));
 }
 root.CDMatch3DRugbyPlayer=Object.freeze({
  load,build,tick,
  status:()=>({ready:!!template||!!fallback?.status().ready,realRig:!!template,failed,loading:!!pending&&!template&&!failed,kits:palettes.size,clips:clips.map(c=>c.name)})
 });
})(typeof window!=='undefined'?window:globalThis);
