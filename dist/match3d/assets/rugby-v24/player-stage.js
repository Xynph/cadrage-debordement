'use strict';
/* Qualification hors runtime : 30 clones skinnés indépendants, 3 LOD avec hystérésis.
 * Ne touche pas au moteur sportif, aux sauvegardes, ni au rendu actif du match. */
(function(root){
 function chooseLOD(distance,previous=null){
  if(!Number.isFinite(distance)||distance<0)throw Error('Distance de caméra invalide');
  const low=14,high=38,margin=3;
  if(previous===0)return distance>high+margin?2:distance>low+margin?1:0;
  if(previous===1)return distance<low-margin?0:distance>high+margin?2:1;
  if(previous===2)return distance<low-margin?0:distance<high-margin?1:2;
  return distance<low?0:distance<high?1:2;
 }
 function instantiate(THREE,asset,side){
  if(!asset?.body||!asset?.clips||!asset?.bones||asset.bones.length!==53)throw Error('Asset LOD incomplet : ne pas activer le jeu');
  const from=[],to=[];
  const body=asset.body.clone(true);
  asset.body.traverse(n=>from.push(n));body.traverse(n=>to.push(n));
  if(from.length!==to.length)throw Error('Clone incomplet');
  const cloneByOriginal=new Map(from.map((n,i)=>[n,to[i]]));
  const skeletonCache=new Map();let meshes=0;
  for(let i=0;i<from.length;i++){
   const original=from[i],copy=to[i];
   if(!original.isSkinnedMesh)continue;
   if(!original.skeleton||original.skeleton.bones.length!==53)throw Error('Rig source incomplet');
   const clonedBones=original.skeleton.bones.map(b=>cloneByOriginal.get(b));
   if(clonedBones.some(b=>!b||b===original))throw Error('Os de clone absent ou partage');
   const key=original.skeleton.bones.map(b=>b.uuid).join(':');
   if(!skeletonCache.has(key))skeletonCache.set(key,new THREE.Skeleton(clonedBones,original.skeleton.boneInverses.map(m=>m.clone())));
   copy.bind(skeletonCache.get(key),original.bindMatrix.clone());
   copy.geometry=original.geometry; // Geometry immutable shared between players.
   copy.geometry.userData=copy.geometry.userData||{};
   copy.geometry.userData.cdMatch3DReusable=true;
   // Materials cloned per player; never tint the source/model of the other team.
   copy.material=Array.isArray(original.material)?original.material.map(m=>m.clone()):original.material.clone();
   const materials=Array.isArray(copy.material)?copy.material:[copy.material];
   for(const mat of materials){
    if(mat.color&&/Cloth_tshirt/i.test(original.name))mat.color.setHex(side===1?0x228bd2:0xe07836);
    if(mat.color&&/Cloth_shorts/i.test(original.name))mat.color.setHex(side===1?0x172a47:0x263444);
   }
   meshes++;
  }
  if(meshes<4)throw Error('Quatre maillages habillés requis');
  const mixer=new THREE.AnimationMixer(body);
  return {body,mixer,meshes,bones:asset.bones.map(b=>cloneByOriginal.get(b)),lod:asset.lod,side,clips:asset.clips};
 }
 function retarget(THREE,assets,model,camera){
  if(!model?.body||!Number.isInteger(model.lod)||model.lod<0||model.lod>2)throw Error('Modele LOD invalide');
  if(!camera||!Number.isFinite(camera.x)||!Number.isFinite(camera.z))throw Error('Camera invalide');
  if(!Array.isArray(assets)||assets.length!==3||assets.some((a,i)=>a?.lod!==i))throw Error('Trois LOD requis');
  const p=model.body.position;
  const next=chooseLOD(Math.hypot(p.x-camera.x,p.z-camera.z),model.lod);
  if(next===model.lod)return model;
  const replacement=instantiate(THREE,assets[next],model.side);
  replacement.body.position.copy(p);
  replacement.body.rotation.copy(model.body.rotation);
  replacement.body.scale.copy(model.body.scale);
  replacement.id=model.id;
  replacement.lodChangedFrom=model.lod;
  // No mutation of match state; remove old scene object in the caller after swap.
  return replacement;
 }
 function stage(THREE,assets,players,camera){
  if(!Array.isArray(assets)||assets.length!==3||assets.some((a,i)=>!a||a.lod!==i))throw Error('3 LOD validés requis');
  if(!Array.isArray(players)||players.length!==30||new Set(players.map(p=>p.id)).size!==30)throw Error('30 identifiants joueurs indépendants requis');
  const groups=[];
  for(const player of players){
   const d=Math.hypot(player.x-camera.x,player.z-camera.z);
   const lod=chooseLOD(d),model=instantiate(THREE,assets[lod],player.side);
   model.body.position.set(player.x,0,player.z);
   model.id=player.id;groups.push(model);
  }
  return groups;
 }
 root.CDMatch3DV24Stage=Object.freeze({chooseLOD,instantiate,retarget,stage});
})(typeof window!=='undefined'?window:globalThis);
