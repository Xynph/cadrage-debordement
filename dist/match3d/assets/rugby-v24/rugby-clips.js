'use strict';
/* Clips rugby originaux CC0 : os CharacterCreator, rendu uniquement.
 * Cinématique Work : objectifs de poignets, IK épaule/coude et appui aux poses clés ; contact complet non qualifié.
 * Les rotations locales sont calculées depuis le repos, sans moteur sportif. */
(function(root){
 // Analytical two-bone IK in world coordinates, then converted to local rotations.
 function solveArm(THREE,upper,lower,hand,target,pole){
  let root=upper;while(root.parent)root=root.parent;
  const update=()=>root.updateMatrixWorld(true),pos=b=>b.getWorldPosition(new THREE.Vector3());
  update();const a=pos(upper),b=pos(lower),c=pos(hand),l1=a.distanceTo(b),l2=b.distanceTo(c);
  if(l1<1e-5||l2<1e-5)throw Error('Longueur de bras invalide');
  const direction=target.clone().sub(a),distance=THREE.MathUtils.clamp(direction.length(),Math.abs(l1-l2)+1e-5,l1+l2-1e-5);direction.normalize();
  const bend=pole.clone().sub(a);bend.addScaledVector(direction,-bend.dot(direction));
  if(bend.lengthSq()<1e-8)bend.set(1,0,0).addScaledVector(direction,-direction.x);
  bend.normalize();
  const along=(l1*l1-l2*l2+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,l1*l1-along*along));
  const elbow=a.clone().addScaledVector(direction,along).addScaledVector(bend,height),wrist=a.clone().addScaledVector(direction,distance);
  function aim(bone,child,goal){
   const origin=pos(bone),from=pos(child).sub(origin).normalize(),to=goal.clone().sub(origin).normalize();
   const delta=new THREE.Quaternion().setFromUnitVectors(from,to),world=bone.getWorldQuaternion(new THREE.Quaternion());
   const parent=bone.parent?bone.parent.getWorldQuaternion(new THREE.Quaternion()):new THREE.Quaternion();
   bone.quaternion.copy(parent.invert().multiply(delta.multiply(world))).normalize();update();
  }
  aim(upper,lower,elbow);aim(lower,hand,wrist);
 }
 // Context-aware, paired-rig contact probe. The carrier's actual torso determines
 // both targets: there is no fake mesh, collision claim or engine mutation.
 // Apply after sampling the tackle clip; clip-only fallback remains unchanged.
 function wrapCarrier(THREE,tacklerBones,carrierBones,blend=1){
  const get=(bones,name)=>{const b=bones.find(b=>b.name===name);if(!b)throw Error('Os contact manquant : '+name);return b;};
  const point=b=>b.getWorldPosition(new THREE.Vector3());
  const torso=point(get(carrierBones,'spine_03'));
  const shoulderL=get(tacklerBones,'upperarm_l'),shoulderR=get(tacklerBones,'upperarm_r');
  const shoulders=point(shoulderL).add(point(shoulderR)).multiplyScalar(.5);
  const toward=torso.clone().sub(shoulders);toward.y=0;
  if(toward.lengthSq()<1e-6)throw Error('Direction de contact indefinie');
  toward.normalize();
  const lateral=new THREE.Vector3(-toward.z,0,toward.x);
  const amount=THREE.MathUtils.clamp(blend,0,1);
  const measurements={};
  for(const [side,sign]of [['l',1],['r',-1]]){
   const upper=get(tacklerBones,'upperarm_'+side),lower=get(tacklerBones,'lowerarm_'+side),hand=get(tacklerBones,'hand_'+side);
   const current=point(hand);
   // Place wrists behind the carrier's torso, on opposite sides, to aim
   // for a genuine two-arm wrap rather than an ungrounded forward gesture.
   const target=torso.clone().addScaledVector(lateral,sign*.16).addScaledVector(toward,.095);
   target.y-=.14;
   const goal=current.clone().lerp(target,amount);
   const pole=point(upper).addScaledVector(lateral,sign*.42).add(new THREE.Vector3(0,-.18,0));
   solveArm(THREE,upper,lower,hand,goal,pole);
   measurements[side]={distance:point(hand).distanceTo(target),target:target.toArray()};
  }
  return measurements;
 }
 // Coordinated two-rig fall demonstrator. Alters only the actual bone/root
 // transforms of two independent rigs in the isolated qualification scene.
 // Caller must resample the original clip and restore base transforms each frame.
 function coordinateFall(THREE,tackler,carrier,progress,bases){
  const clamp=THREE.MathUtils.clamp, p=clamp(progress,0,2);
  const smooth=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
  const recovery=p<=1?1:1-smooth((p-1)/.85);
  const onset=smooth((Math.min(p,1)-.25)/.75)*recovery, settle=smooth((Math.min(p,1)-.63)/.37)*recovery;
  const get=(rig,name)=>{const b=rig.bones.find(x=>x.name===name);if(!b)throw Error('Os chute absent : '+name);return b;};
  if(!bases||!bases.tackler||!bases.carrier)throw Error('Bases de contact requises');
  // Gradual translational impulse and rotational loss of balance for BOTH rigs.
  // Keep meshes, skinned materials and independent armature hierarchy unchanged.
  tackler.body.position.copy(bases.tackler.position).add(new THREE.Vector3(0,-.22*onset,.06*onset));
  carrier.body.position.copy(bases.carrier.position).add(new THREE.Vector3(0,-.32*onset,.26*onset));
  tackler.body.quaternion.copy(bases.tackler.quaternion).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),.47*onset));
  carrier.body.quaternion.copy(bases.carrier.quaternion).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),.78*onset));
  // A controlled roll and leg bend, not an artificial low-poly body proxy.
  for(const [rig,base,lean,legs]of [[tackler,bases.tackler,.32,.48],[carrier,bases.carrier,.46,.80]]){
   for(const name of ['spine_02','thigh_l','thigh_r','calf_l','calf_r']){
    const original=base.joints?.[name];if(!original)throw Error('Pose de base manquante : '+name);
    get(rig,name).quaternion.copy(original);
   }
   get(rig,'spine_02').rotateX(lean*onset);
   get(rig,'thigh_l').rotateX(-legs*onset);
   get(rig,'thigh_r').rotateX(-legs*onset);
   get(rig,'calf_l').rotateX(legs*.8*settle);
   get(rig,'calf_r').rotateX(legs*.8*settle);
  }
  const point=(rig,name)=>get(rig,name).getWorldPosition(new THREE.Vector3());
  tackler.body.updateMatrixWorld(true);carrier.body.updateMatrixWorld(true);
  // Whole-body landing, pivoting the real rig around its pelvis rather than
  // only folding knees/spine while leaving both players standing.
  // On approach the correction is zero; at recovery it smoothly vanishes.
  const landing=smooth((Math.min(p,1)-.35)/.55)*recovery;
  for(const rig of [tackler,carrier]){
   const hip=point(rig,'pelvis'),head=point(rig,'head');
   const longAxis=head.clone().sub(hip).normalize();
   const forward=new THREE.Vector3(0,0,1).applyQuaternion(rig.body.getWorldQuaternion(new THREE.Quaternion()));
   forward.y=0;
   if(forward.lengthSq()<1e-6)forward.set(0,0,1);
   forward.normalize();
   const target=new THREE.Quaternion().setFromUnitVectors(longAxis,forward);
   const turn=new THREE.Quaternion().slerp(target,landing);
   rig.body.quaternion.premultiply(turn).normalize();
   rig.body.updateMatrixWorld(true);
   // Preserve the world-space hip pivot through the full-body rotation.
   rig.body.position.add(hip.sub(point(rig,'pelvis')));
   rig.body.updateMatrixWorld(true);
   // A torso is not landed while the hips hover over bent, dangling legs.
   // Lower the actual pelvis and put both real feet behind it with two-bone IK.
   const pelvis=point(rig,'pelvis');
   rig.body.position.y+=landing*(.34-pelvis.y);
   rig.body.updateMatrixWorld(true);
   const hipNow=point(rig,'pelvis');
   const longDirection=point(rig,'head').sub(hipNow);
   longDirection.y=0;
   if(longDirection.lengthSq()<1e-6)longDirection.copy(forward);
   longDirection.normalize();
   const sideways=new THREE.Vector3(-longDirection.z,0,longDirection.x);
   for(const [side,sign]of [['l',1],['r',-1]]){
    const thigh=get(rig,'thigh_'+side),calf=get(rig,'calf_'+side),foot=get(rig,'foot_'+side);
    const initial=point(rig,'foot_'+side);
    const proneFoot=hipNow.clone().addScaledVector(longDirection,-.72).addScaledVector(sideways,sign*.14);
    proneFoot.y=.12;
    const goal=initial.lerp(proneFoot,landing);
    const pole=hipNow.clone().addScaledVector(longDirection,-.33).addScaledVector(sideways,sign*.30);
    pole.y=.35;
    solveArm(THREE,thigh,calf,foot,goal,pole);
   }
  }
  // Ground alignment uses deformed GLB vertices (not skeleton-only landmarks
  // or a cosmetic body proxy); sample a bounded set of real skinned vertices.
  const meshFloor=rig=>{
   rig.body.updateMatrixWorld(true);
   let min=Infinity,vertices=0;
   rig.body.traverse(mesh=>{
    if(!mesh.isSkinnedMesh)return;
    const positions=mesh.geometry.getAttribute('position');
    if(!positions)return;
    const stride=Math.max(1,Math.floor(positions.count/350));
    const v=new THREE.Vector3();
    for(let i=0;i<positions.count;i+=stride){
     mesh.boneTransform(i,v.fromBufferAttribute(positions,i));
     mesh.localToWorld(v);min=Math.min(min,v.y);vertices++;
    }
   });
   if(!Number.isFinite(min)||vertices<30)throw Error('Sol maillage skin indisponible');
   return {min,vertices};
  };
  // Separate the actual upper-torso joints, avoiding unphysical overlap of
  // the torso centres. This is a proxy clearance, NOT exact mesh collision.
  const delta=point(carrier,'spine_03').sub(point(tackler,'spine_03'));
  const horizontal=new THREE.Vector3(delta.x,0,delta.z);
  const length=horizontal.length();
  if(length<.38){
   if(length<1e-6)horizontal.set(0,0,1);else horizontal.divideScalar(length);
   carrier.body.position.addScaledVector(horizontal,.38-length);
   carrier.body.updateMatrixWorld(true);
  }
  // Prevent bone landmarks from falling below a basic ground plane. This
  // is deliberately only a skeleton-ground constraint, not cloth collision.
  for(const rig of [tackler,carrier]){
   const landmarks=['foot_l','foot_r','hand_l','hand_r','head'].filter(name=>rig.bones.some(b=>b.name===name));
   const lowest=Math.min(...landmarks.map(name=>point(rig,name).y));
   if(lowest<.045){rig.body.position.y+=.045-lowest;rig.body.updateMatrixWorld(true);}
  }
  // Align actual surface to the field once the body rotates into its landing.
  // Never shift the original standing pose at progress=0 or recovery=1.85.
  const floorCorrection=smooth((Math.min(p,1)-.3)/.6)*recovery;
  const groundSamples=[];
  for(const rig of [tackler,carrier]){
   const before=meshFloor(rig);
   rig.body.position.y+=(.025-before.min)*floorCorrection;
   rig.body.updateMatrixWorld(true);
   const after=meshFloor(rig);
   const pelvis=point(rig,'pelvis'),head=point(rig,'head');
   groundSamples.push({minMeshY:after.min,vertices:after.vertices,pelvisY:pelvis.y,
    headY:head.y,verticalTorsoRatio:Math.abs(head.y-pelvis.y)/head.distanceTo(pelvis)});
  }
  return {progress:p,onset,settle,landing,groundSamples,torsoSeparationM:point(tackler,'spine_03').distanceTo(point(carrier,'spine_03')),
   horizontalTorsoGapM:new THREE.Vector2(point(tackler,'spine_03').x-point(carrier,'spine_03').x,point(tackler,'spine_03').z-point(carrier,'spine_03').z).length(),
   tacklerRoot:tackler.body.position.toArray(),carrierRoot:carrier.body.position.toArray()};
 }
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
    [.24,{pelvis:[0,-.08,0],spine_02:[-.09,.18,0],spine_03:[-.08,.10,0],clavicle_l:[0,0,0.048],upperarm_l:[-0.540,0,0.048],clavicle_r:[0,0,-0.048],upperarm_r:[-0.563,0,-0.048],lowerarm_l:[-.48,0,0],lowerarm_r:[-.27,0,0]}],
    [.42,{pelvis:[0,.08,0],spine_02:[.04,.34,0],spine_03:[.08,.16,0],clavicle_l:[0,0,0.048],upperarm_l:[-0.630,0,0.048],clavicle_r:[0,0,-0.048],upperarm_r:[-0.680,0,-0.048],lowerarm_l:[-.14,0,0],lowerarm_r:[.08,0,0]}],
    [.72,{}]]},
   {name:'rugby_tackle',duration:.92,keys:[
    [0,{spine_02:[.10,0,0],clavicle_l:[0,0,0.090],upperarm_l:[-0.300,0,0.090],clavicle_r:[0,0,-0.090],upperarm_r:[-0.300,0,-0.090]}],
    [.24,{pelvis:[.22,0,0],spine_02:[.48,.08,0],spine_03:[.12,0,0],clavicle_l:[0,0,0.045],upperarm_l:[-0.530,0,0.045],lowerarm_l:[-.20,0,0],clavicle_r:[0,0,-0.045],upperarm_r:[-0.470,0,-0.045],lowerarm_r:[-.32,0,0],thigh_l:[-.4,0,0],thigh_r:[-.32,0,0]}],
    [.55,{pelvis:[.46,0,0],spine_02:[.65,.10,0],spine_03:[.16,0,0],clavicle_l:[0,0,0.042],upperarm_l:[-0.700,0,0.042],lowerarm_l:[-.08,0,0],clavicle_r:[0,0,-0.042],upperarm_r:[-0.630,0,-0.042],lowerarm_r:[-.18,0,0],thigh_l:[-.62,0,0],thigh_r:[-.54,0,0],calf_l:[.4,0,0],calf_r:[.4,0,0]}],
    [.92,{}]]},
   {name:'rugby_recover',duration:1.15,keys:[
    [0,{pelvis:[.8,0,0],spine_02:[.6,0,0],clavicle_l:[0,0,0.081],upperarm_l:[-0.570,0,0.081],clavicle_r:[0,0,-0.081],upperarm_r:[-0.570,0,-0.081],thigh_l:[-1.0,0,0],thigh_r:[-1.0,0,0],calf_l:[1.2,0,0],calf_r:[1.2,0,0]}],
    [.4,{pelvis:[.4,0,0],spine_02:[.45,0,0],clavicle_l:[0,0,0.054],upperarm_l:[-0.450,0,0.054],clavicle_r:[0,0,-0.054],upperarm_r:[-0.450,0,-0.054],thigh_l:[-.7,0,0],thigh_r:[-.7,0,0],calf_l:[.9,0,0],calf_r:[.9,0,0]}],
    [.85,{pelvis:[.14,0,0],spine_02:[.15,0,0],clavicle_l:[0,0,0.045],upperarm_l:[-0.150,0,0.045],clavicle_r:[0,0,-0.045],upperarm_r:[-0.150,0,-0.045],thigh_l:[-.2,0,0],thigh_r:[-.2,0,0]}],
    [1.15,{}]]}
  ];
  const originals=new Map(bones.map(b=>[b,b.quaternion.clone()])),originalPositions=new Map(bones.map(b=>[b,b.position.clone()]));
  const hierarchy=bones.every(b=>b.isBone)&&map.get('hand_l')&&map.get('hand_r');
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
   if(hierarchy){
    const solved=new Map(['upperarm_l','upperarm_r','lowerarm_l','lowerarm_r'].map(n=>[n,[]]));
    const pelvisPositions=[];
    for(const [time,pose]of spec.keys){
     for(const b of bones)b.position.copy(originalPositions.get(b));
     for(const b of bones){const angles=pose[b.name]||[0,0,0];b.quaternion.copy(originals.get(b)).multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(...angles,'XYZ')));}
     let top=bones[0];while(top.parent)top=top.parent;top.updateMatrixWorld(true);
     if(map.has('foot_l')&&map.has('foot_r')){
      const minFoot=Math.min(...['foot_l','foot_r'].map(n=>map.get(n).getWorldPosition(new THREE.Vector3()).y));
      const pelvis=map.get('pelvis'),parent=pelvis.parent.getWorldQuaternion(new THREE.Quaternion()).invert();
      pelvis.position.add(new THREE.Vector3(0,.069-minFoot,0).applyQuaternion(parent));top.updateMatrixWorld(true);
     }
     pelvisPositions.push(...map.get('pelvis').position.toArray());
     const shoulderL=map.get('upperarm_l').getWorldPosition(new THREE.Vector3()),shoulderR=map.get('upperarm_r').getWorldPosition(new THREE.Vector3());
     const centre=shoulderL.clone().add(shoulderR).multiplyScalar(.5);
     let spread=.055,down=-.23,forward=.30,lateral=0;
     if(spec.name==='rugby_pass'){
      lateral=time===0?-.16:time<.3?.03:time<.6?.25:0;down=time<.3?-.22:-.12;forward=time<.3?.30:.35;
     }else if(spec.name==='rugby_tackle'){
      spread=time<.3?.18:.055;lateral=time<.3?.08:.25;down=-.16;forward=time<.3?.30:.32;
     }
     for(const [side,sign]of [['l',1],['r',-1]]){
      const target=centre.clone().add(new THREE.Vector3(lateral+sign*spread,down,forward+(spec.name==='rugby_tackle'&&time>=.3?sign*.08:0)));
      const pole=centre.clone().add(new THREE.Vector3(sign*.5,-.28,.10));
      solveArm(THREE,map.get('upperarm_'+side),map.get('lowerarm_'+side),map.get('hand_'+side),target,pole);
     }
     for(const [name,values]of solved)values.push(...map.get(name).quaternion.toArray());
    }
    tracks.push(new THREE.VectorKeyframeTrack('pelvis.position',spec.keys.map(k=>k[0]),pelvisPositions));
    for(const [name,values]of solved){const i=tracks.findIndex(t=>t.name===name+'.quaternion');const track=new THREE.QuaternionKeyframeTrack(name+'.quaternion',spec.keys.map(k=>k[0]),values);if(i>=0)tracks[i]=track;else tracks.push(track);}
   }
   clips.push(new THREE.AnimationClip(spec.name,spec.duration,tracks));
  }
  for(const b of bones){b.quaternion.copy(originals.get(b));b.position.copy(originalPositions.get(b));}
  if(hierarchy){let top=bones[0];while(top.parent)top=top.parent;top.updateMatrixWorld(true);}
  return clips;
 }
 root.CDMatch3DV24RugbyClips=Object.freeze({create,solveArm,wrapCarrier,coordinateFall});
})(typeof window!=='undefined'?window:globalThis);
