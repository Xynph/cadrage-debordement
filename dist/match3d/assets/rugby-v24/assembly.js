/* Qualification CC0 uniquement : aucun raccordement au moteur du jeu. */
(function(root){
'use strict';
const morphs={gender_male:1,muscle_max:.8,weight_max:.15,corr_gender_male__muscle_max:.8,corr_gender_male__weight_max:.15,corr_weight_max__muscle_max:.12};
function matchBones(source,target){return source.map(b=>{const found=target.find(t=>t.name===b.name);if(!found)throw Error('Joint absent : '+b.name);return found;});}
async function load(THREE,base){
 const loader=new THREE.GLTFLoader();
 const files=['base_body_anim','clothing_tshirt','clothing_shorts','clothing_shoes'];
 const models=await Promise.all(files.map(f=>loader.loadAsync(base+f+'.glb')));
 const body=models[0].scene;body.updateMatrixWorld(true);let skeleton;
 body.traverse(n=>{if(n.isSkinnedMesh&&!skeleton)skeleton=n.skeleton;});
 if(!skeleton||skeleton.bones.length!==53)throw Error('Rig 53 joints requis');
 for(const [i,gltf]of models.entries()){
  gltf.scene.updateMatrixWorld(true);const meshes=[];gltf.scene.traverse(n=>{if(n.isMesh)meshes.push(n);});
  for(const mesh of meshes){
   // Baking avoids the WebGL limit on simultaneous morph attributes.
   const geometry=mesh.geometry.clone(),pos=geometry.attributes.position.clone();
   const deltas=geometry.morphAttributes.position||[];
   for(const [name,value]of Object.entries(morphs)){
    const delta=deltas[mesh.morphTargetDictionary?.[name]];if(!delta)continue;
    for(let k=0;k<pos.array.length;k++)pos.array[k]+=delta.array[k]*value;
   }
   geometry.setAttribute('position',pos);geometry.morphAttributes={};geometry.computeVertexNormals();geometry.computeBoundingSphere();
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
 const mixer=new THREE.AnimationMixer(body);
 return {body,mixer,clips:models[0].animations,bones:skeleton.bones,morphs};
}
root.CDV24Assembly={load,matchBones};
})(globalThis);
