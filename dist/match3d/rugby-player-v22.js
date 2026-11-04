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
 const fabrics=new Map();
 function textile(T,side,part){
  const key=side+':'+part;
  if(fabrics.has(key))return fabrics.get(key);
  if(typeof document==='undefined'||!T.CanvasTexture)return null;
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=256;
  const ctx=canvas.getContext('2d');if(!ctx)return null;
  const dark=side==='home'?'#d85c26':'#116ea8';
  const light=side==='home'?'#ffb16b':'#54c8f5';
  ctx.fillStyle=part==='Shirt2'?light:dark;ctx.fillRect(0,0,256,256);
  // Restrained woven-fabric microstructure: local procedural PBR, no third-party bitmap.
  for(let y=0;y<256;y+=4){
   ctx.fillStyle='rgba(255,255,255,0.085)';ctx.fillRect(0,y,256,1);
   ctx.fillStyle='rgba(0,0,0,0.09)';ctx.fillRect(0,y+2,256,1);
  }
  for(let x=0;x<256;x+=6){
   ctx.fillStyle='rgba(255,255,255,0.045)';ctx.fillRect(x,0,1,256);
  }
  ctx.fillStyle=side==='home'?'#ffe8bf':'#e8f7ff';
  if(part==='Shirt'){
   ctx.fillRect(100,0,14,256);ctx.fillRect(142,0,14,256);
   ctx.fillStyle='rgba(18,34,47,0.40)';ctx.fillRect(0,208,256,10);
  }else{ctx.fillRect(0,32,256,14);ctx.fillRect(0,203,256,14);}
  const map=new T.CanvasTexture(canvas);
  if(T.sRGBEncoding!==undefined)map.encoding=T.sRGBEncoding;
  map.wrapS=T.RepeatWrapping;map.wrapT=T.RepeatWrapping;
  map.anisotropy=2;map.needsUpdate=true;
  fabrics.set(key,map);return map;
 }
 function decorateMaterial(T,mat,side,part){
  if(part!=='Shirt'&&part!=='Shirt2')return;
  const texture=textile(T,side,part);
  if(texture){
   mat.map=texture;if(mat.color)mat.color.setHex(0xffffff);
  }
  // MeshStandardMaterial remains physically-based, matte textile (not glossy plastic).
  mat.roughness=.91;mat.metalness=0;
 }
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
  const skeletonCache=new Map();
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
   // A GLB with nine material primitives references the same joint set.
   // Reuse one Skeleton per *player* to avoid nine bone textures per rig.
   const key=bones.map(b=>b.name||'').join('|');
   if(!skeletonCache.has(key))skeletonCache.set(key,new T.Skeleton(bones,from.skeleton.boneInverses.map(m=>m.clone())));
   to.skeleton=skeletonCache.get(key);
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
     decorateMaterial(T,m,side,keyName);
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
  const joints={};clone.traverse(n=>{if(n.isBone&&n.name)joints[n.name]=n;});
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
  group.userData.premiumJoints=joints;group.userData.premiumV23=true;
  return group;
 }
 function tick(group,delta,pace=1,fall=false,cue=null){
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
  // Rugby action accents are strictly render-only; the underlying animation always wins.
  const joints=ud.premiumJoints||{},c=cue||{};
  const brace=Math.max(0,Math.min(1,Number(c.brace)||0));
  const pass=Math.max(0,Math.min(1,Number(c.pass)||0));
  const recover=Math.max(0,Math.min(1,Number(c.recovery)||0));
  const left=joints['UpperArm.L'],right=joints['UpperArm.R'];
  if(left?.rotation){left.rotation.x+=brace*.32+pass*.58-recover*.12;left.rotation.z+=pass*.25;}
  if(right?.rotation){right.rotation.x+=brace*.32+pass*.42-recover*.12;right.rotation.z-=pass*.27;}
  for(const key of ['LowerArm.L','LowerArm.R'])if(joints[key]?.rotation)joints[key].rotation.x-=brace*.26+pass*.48;
  if(joints.Torso?.rotation)joints.Torso.rotation.x+=brace*.12+pass*.16-recover*.1;
 }
 root.CDMatch3DRugbyPlayer=Object.freeze({
  load,build,tick,
  status:()=>({ready:!!template||!!fallback?.status().ready,realRig:!!template,failed,loading:!!pending&&!template&&!failed,kits:palettes.size,clothTextures:fabrics.size,materials:'MeshStandardMaterial PBR',clips:clips.map(c=>c.name)})
 });
})(typeof window!=='undefined'?window:globalThis);
