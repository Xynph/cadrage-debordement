/* Qualification CC0 uniquement : aucun raccordement au moteur du jeu. */
(function(root){
'use strict';
const morphs={gender_male:1,muscle_max:.8,weight_max:.15,corr_gender_male__muscle_max:.8,corr_gender_male__weight_max:.15,corr_weight_max__muscle_max:.12};
function matchBones(source,target){return source.map(b=>{const found=target.find(t=>t.name===b.name);if(!found)throw Error('Joint absent : '+b.name);return found;});}
function bakePosition(THREE,source,targets,dictionary,weights){
 const result=new THREE.Float32BufferAttribute(new Float32Array(source.count*3),3);
 const getters=['getX','getY','getZ'];
 for(let v=0;v<source.count;v++)for(let axis=0;axis<3;axis++){
  let value=source[getters[axis]](v);
  for(const [name,weight]of Object.entries(weights)){
   const delta=targets[dictionary?.[name]];
   // BufferAttribute getters decode normalized integer glTF accessors.
   if(delta)value+=delta[getters[axis]](v)*weight;
  }
  result.array[v*3+axis]=value;
 }
 return result;
}
function restoreSparseValues(attribute,indices,values){
 if(attribute.isInterleavedBufferAttribute)throw Error('Sparse interleaved non pris en charge');
 for(let i=0;i<indices.length;i++)for(let c=0;c<attribute.itemSize;c++)
  attribute.array[indices[i]*attribute.itemSize+c]=values[i*attribute.itemSize+c];
 attribute.needsUpdate=true;
}
async function repairNormalizedSparse(gltf){
 const parser=gltf.parser,types={5120:Int8Array,5121:Uint8Array,5122:Int16Array,5123:Uint16Array,5125:Uint32Array};
 await Promise.all(parser.json.accessors.map(async(def,index)=>{
  if(!def.normalized||!def.sparse)return;
  const sparse=def.sparse;
  const [attribute,ib,vb]=await Promise.all([parser.getDependency('accessor',index),parser.getDependency('bufferView',sparse.indices.bufferView),parser.getDependency('bufferView',sparse.values.bufferView)]);
  restoreSparseValues(attribute,new types[sparse.indices.componentType](ib,sparse.indices.byteOffset||0,sparse.count),new types[def.componentType](vb,sparse.values.byteOffset||0,sparse.count*attribute.itemSize));
 }));
}
// Only removes body triangles hidden by the shirt, never the garment geometry.
// The guard keeps the original anatomy if GLB transforms/bounds are inconsistent.
function coverSkinByShirt(THREE,body){
 const meshes=[];body.updateMatrixWorld(true);
 body.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n);});
 const skin=meshes.find(n=>n.name==='Body'),shirt=meshes.find(n=>n.name==='Cloth_tshirt');
 if(!skin||!shirt)return {removed:0,reason:'meshes absent'};
 const geom=skin.geometry,attr=geom.getAttribute('position');
 const aabb=new THREE.Box3().setFromBufferAttribute(shirt.geometry.getAttribute('position'));
 const toSkin=new THREE.Matrix4().copy(skin.matrixWorld).invert().multiply(shirt.matrixWorld);
 aabb.applyMatrix4(toSkin);
 if(aabb.isEmpty()||aabb.max.y-aabb.min.y<.25||aabb.max.y-aabb.min.y>1.5)return {removed:0,reason:'bornes incompatibles'};
 const oldIndex=geom.getIndex(),count=oldIndex?oldIndex.count:attr.count;
 const groups=geom.groups.length?geom.groups:[{start:0,count,materialIndex:0}];
 const keep=[],newGroups=[];let removed=0;
 const vertex=new THREE.Vector3();
 // Torso interior: leave collar, hem and sleeve borders intact.
 const minY=aabb.min.y+.055,maxY=aabb.max.y-.075;
 const minX=aabb.min.x+.035,maxX=aabb.max.x-.035;
 const minZ=aabb.min.z+.035,maxZ=aabb.max.z-.035;
 if(maxY<=minY||maxX<=minX||maxZ<=minZ)return {removed:0,reason:'marge non valide'};
 const get=(i)=>oldIndex?oldIndex.getX(i):i;
 for(const group of groups){
  const start=keep.length,end=Math.min(count,group.start+group.count);
  for(let i=group.start;i+2<end;i+=3){
   const ids=[get(i),get(i+1),get(i+2)];
   let cx=0,cy=0,cz=0;
   for(const id of ids){vertex.fromBufferAttribute(attr,id);cx+=vertex.x/3;cy+=vertex.y/3;cz+=vertex.z/3;}
   const hidden=cx>minX&&cx<maxX&&cy>minY&&cy<maxY&&cz>minZ&&cz<maxZ;
   if(hidden)removed++;else keep.push(...ids);
  }
  newGroups.push({start,count:keep.length-start,materialIndex:group.materialIndex||0});
 }
 const triangles=count/3;
 if(removed<8||removed>triangles*.65)return {removed:0,reason:'masque refuse',candidates:removed};
 geom.setIndex(keep);geom.clearGroups();
 newGroups.forEach(g=>geom.addGroup(g.start,g.count,g.materialIndex));
 geom.computeBoundingBox();geom.computeBoundingSphere();
 return {removed,remaining:keep.length/3};
}

async function load(THREE,base,options={}){
 const loader=new THREE.GLTFLoader();
 const files=['base_body_anim','clothing_tshirt','clothing_shorts','clothing_shoes'];
 const models=await Promise.all(files.map(f=>loader.loadAsync(base+f+(options.lod===undefined?'':'-lod'+options.lod)+'.glb')));
 await Promise.all(models.map(repairNormalizedSparse));
 const body=models[0].scene;body.updateMatrixWorld(true);let skeleton;
 body.traverse(n=>{if(n.isSkinnedMesh&&!skeleton)skeleton=n.skeleton;});
 if(!skeleton||skeleton.bones.length!==53)throw Error('Rig 53 joints requis');
 for(const [i,gltf]of models.entries()){
  gltf.scene.updateMatrixWorld(true);const meshes=[];gltf.scene.traverse(n=>{if(n.isMesh)meshes.push(n);});
  for(const mesh of meshes){
   // Baking avoids the WebGL limit on simultaneous morph attributes.
   const geometry=mesh.geometry.clone();
   const pos=bakePosition(THREE,geometry.attributes.position,
     geometry.morphAttributes.position||[],mesh.morphTargetDictionary,morphs);
   geometry.setAttribute('position',pos);geometry.morphAttributes={};geometry.computeVertexNormals();geometry.computeBoundingBox();geometry.computeBoundingSphere();
   mesh.geometry=geometry;mesh.morphTargetInfluences=[];mesh.morphTargetDictionary={};
   mesh.frustumCulled=false;
   if(i){
    if(!mesh.isSkinnedMesh)throw Error('Vêtement sans skin');
    const mapped=matchBones(mesh.skeleton.bones,skeleton.bones);
    const shared=new THREE.Skeleton(mapped,mesh.skeleton.boneInverses.map(m=>m.clone()));
    mesh.bind(shared,mesh.bindMatrix.clone());body.attach(mesh);
    mesh.material=mesh.material.clone();mesh.material.color.set(i===1?0x175aa5:i===2?0xf1f2ef:0x161c22);mesh.material.roughness=.85;
   }
  }
 }
 const cover=coverSkinByShirt(THREE,body);
 const mixer=new THREE.AnimationMixer(body);
 const rugby=(options.rugby&&root.CDMatch3DV24RugbyClips)?root.CDMatch3DV24RugbyClips.create(THREE,skeleton.bones):[];
 return {body,mixer,clips:models[0].animations.concat(rugby),bones:skeleton.bones,morphs,lod:options.lod??null,cover};
}
root.CDV24Assembly={load,matchBones,bakePosition,restoreSparseValues,coverSkinByShirt};
})(globalThis);
