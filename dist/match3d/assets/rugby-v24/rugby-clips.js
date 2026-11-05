'use strict';
/* Clips rugby originaux CC0 : os CharacterCreator, rendu uniquement.
 * Essai cinématique v24d : poses compactes et clavicules animées pour répartir l'élévation des bras.
 * Les rotations sont relatives au repos de chaque os, sans moteur sportif. */
(function(root){
 function create(THREE,bones){
  if(!THREE?.AnimationClip||!THREE?.QuaternionKeyframeTrack)throw Error('Three.js animations requises');
  const map=new Map(bones.map(b=>[b.name,b]));
  for(const n of ['pelvis','spine_02','spine_03','clavicle_l','clavicle_r','upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','thigh_l','thigh_r','calf_l','calf_r']){
   if(!map.has(n))throw Error('Rig rugby os manquant : '+n);
  }
  const specs=[
   {name:'rugby_carry',duration:.8,keys:[
    [0,{clavicle_l:[0,0,0.081],upperarm_l:[-0.413,0,0.081],lowerarm_l:[-.7,0,0],clavicle_r:[0,0,-0.090],upperarm_r:[-0.375,0,-0.090],lowerarm_r:[-.7,0,0],spine_03:[.08,0,0]}],
    [.3,{clavicle_l:[0,0,0.090],upperarm_l:[-0.563,0,0.090],lowerarm_l:[-.9,0,0],clavicle_r:[0,0,-0.068],upperarm_r:[-0.413,0,-0.068],lowerarm_r:[-.6,0,0],spine_03:[.16,0,0]}],
    [.8,{clavicle_l:[0,0,0.081],upperarm_l:[-0.413,0,0.081],lowerarm_l:[-.7,0,0],clavicle_r:[0,0,-0.090],upperarm_r:[-0.375,0,-0.090],lowerarm_r:[-.7,0,0],spine_03:[.08,0,0]}]]},
   {name:'rugby_pass',duration:.72,keys:[
    [0,{spine_02:[0,-.25,0],clavicle_l:[0,0,0.068],upperarm_l:[-0.525,0,0.068],clavicle_r:[0,0,-0.090],upperarm_r:[-0.488,0,-0.090],lowerarm_l:[-.85,0,0],lowerarm_r:[-.8,0,0]}],
    [.24,{spine_02:[-.05,.1,0],clavicle_l:[0,0,0.054],upperarm_l:[-0.540,0,0.054],clavicle_r:[0,0,-0.054],upperarm_r:[-0.563,0,-0.054],lowerarm_l:[-.3,0,0],lowerarm_r:[-.3,0,0]}],
    [.42,{spine_02:[.04,.4,0],clavicle_l:[0,0,0.072],upperarm_l:[-0.660,0,0.072],clavicle_r:[0,0,-0.072],upperarm_r:[-0.660,0,-0.072],lowerarm_l:[0,0,0],lowerarm_r:[0,0,0]}],
    [.72,{}]]},
   {name:'rugby_tackle',duration:.92,keys:[
    [0,{spine_02:[.10,0,0],clavicle_l:[0,0,0.090],upperarm_l:[-0.300,0,0.090],clavicle_r:[0,0,-0.090],upperarm_r:[-0.300,0,-0.090]}],
    [.24,{pelvis:[.22,0,0],spine_02:[.48,0,0],clavicle_l:[0,0,0.063],upperarm_l:[-0.510,0,0.063],clavicle_r:[0,0,-0.063],upperarm_r:[-0.510,0,-0.063],thigh_l:[-.4,0,0],thigh_r:[-.32,0,0]}],
    [.55,{pelvis:[.46,0,0],spine_02:[.65,0,0],clavicle_l:[0,0,0.072],upperarm_l:[-0.690,0,0.072],clavicle_r:[0,0,-0.072],upperarm_r:[-0.690,0,-0.072],thigh_l:[-.62,0,0],thigh_r:[-.54,0,0],calf_l:[.4,0,0],calf_r:[.4,0,0]}],
    [.92,{}]]},
   {name:'rugby_recover',duration:1.15,keys:[
    [0,{pelvis:[.8,0,0],spine_02:[.6,0,0],clavicle_l:[0,0,0.081],upperarm_l:[-0.570,0,0.081],clavicle_r:[0,0,-0.081],upperarm_r:[-0.570,0,-0.081],thigh_l:[-1.0,0,0],thigh_r:[-1.0,0,0],calf_l:[1.2,0,0],calf_r:[1.2,0,0]}],
    [.4,{pelvis:[.4,0,0],spine_02:[.45,0,0],clavicle_l:[0,0,0.054],upperarm_l:[-0.450,0,0.054],clavicle_r:[0,0,-0.054],upperarm_r:[-0.450,0,-0.054],thigh_l:[-.7,0,0],thigh_r:[-.7,0,0],calf_l:[.9,0,0],calf_r:[.9,0,0]}],
    [.85,{pelvis:[.14,0,0],spine_02:[.15,0,0],clavicle_l:[0,0,0.045],upperarm_l:[-0.150,0,0.045],clavicle_r:[0,0,-0.045],upperarm_r:[-0.150,0,-0.045],thigh_l:[-.2,0,0],thigh_r:[-.2,0,0]}],
    [1.15,{}]]}
  ];
  const clips=[];
  for(const spec of specs){
   const joints=[...new Set(spec.keys.flatMap(k=>Object.keys(k[1])))];
   const tracks=joints.map(name=>{
    const bone=map.get(name);if(!bone)throw Error('Os manquant '+name);
    const times=[],values=[];
    for(const [time,pose] of spec.keys){
     const angles=pose[name]||[0,0,0];
     const delta=new THREE.Quaternion().setFromEuler(new THREE.Euler(...angles,'XYZ'));
     const q=bone.quaternion.clone().multiply(delta).normalize();
     times.push(time);values.push(q.x,q.y,q.z,q.w);
    }
    return new THREE.QuaternionKeyframeTrack(name+'.quaternion',times,values);
   });
   clips.push(new THREE.AnimationClip(spec.name,spec.duration,tracks));
  }
  return clips;
 }
 root.CDMatch3DV24RugbyClips=Object.freeze({create});
})(typeof window!=='undefined'?window:globalThis);
