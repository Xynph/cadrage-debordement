// Original Ekza autoRig/compileRig/solveBoneChannels/plantFeetChannels on
// actual evaluated V25 frame-world bone matrices and authored stance targets.
// NEVER generates fake motion: if source pose cannot be reconstructed, FAIL.
import {readFileSync,writeFileSync} from 'node:fs';
import {expect,test} from 'vitest';
import {Matrix4,Vector3,Quaternion} from 'three';
import {autoRig,compileRig,registerBuiltinRigOps,solveBoneChannels,
        plantFeetChannels,writeControlChannels} from '../src/index';
const source=JSON.parse(readFileSync(process.env.CD_V25_REAL_FRAMES!,'utf8'));
const glb=JSON.parse(readFileSync(process.env.CD_GLB_REST!,'utf8'));
const result:any={schema:'cd-v25-ekza-native-real-19frame-v1',status:'STOP_UNQUALIFIED',
  source:'ACTUAL_V25_FRAME_BONES_AND_AUTHORED_IK_TARGETS',
  originalEkzaUpstream:process.env.CD_EKZA_SHA,
  samples:[],errors:[],limitations:[
  'Pins use authentic source V25 stance target POSITION but current sampled ankle orientation',
  'This is real world IK evaluation, not yet Blender skinning or shoe geometry',
  'No cinematic gait art approval unless paired new Blender renders are inspected'
  ]};
// Original V25 Blender exporter stored m[col][row], i.e. a transposed row-major snapshot.
// Decode that representation explicitly; Ekza boneWorld buffers are column-major.
const captured=(xs:number[])=>new Matrix4().fromArray(xs).transpose();
const native=(xs:number[])=>new Matrix4().fromArray(xs);
const vec=(m:Matrix4)=>new Vector3().setFromMatrixPosition(m);
function xfrm(x:any):Matrix4 {const {t,q,s}=x;
 return new Matrix4().compose(
   new Vector3(...t),new Quaternion(...q),new Vector3(...s));}
function triad(a:Vector3,b:Vector3,c:Vector3) {
 const x=b.clone().sub(a).normalize();
 const y=c.clone().sub(a).addScaledVector(x,-c.clone().sub(a).dot(x)).normalize();
 expect(y.length()).toBeGreaterThan(.001);
 const z=x.clone().cross(y).normalize();
 return new Matrix4().makeBasis(x,y,z);
}
function conversion(g:any,b:any):Matrix4{
 const ga=g.map((x:Matrix4)=>vec(x)),ba=b.map((x:Matrix4)=>vec(x));
 return new Matrix4().makeTranslation(ba[0].x,ba[0].y,ba[0].z)
   .multiply(triad(ba[0],ba[1],ba[2]))
   .multiply(triad(ga[0],ga[1],ga[2]).invert())
   .multiply(new Matrix4().makeTranslation(-ga[0].x,-ga[0].y,-ga[0].z));
}
function dist(a:Matrix4,b:Matrix4):number{return vec(a).distanceTo(vec(b));}
function originalWorldNodes(sk:any):Map<string,Matrix4>{
 const worlds:Matrix4[]=[];const map=new Map<string,Matrix4>();
 for(const n of sk.nodes){
   const local=xfrm(n.restLocal);
   const world=n.parent<0?local:worlds[n.parent].clone().multiply(local);
   worlds[n.index]=world;map.set(n.name,world);
 }
 return map;
}
test('fail-closed 3 LOD × 2 actors × 19 genuine V25 frames original Ekza foot pins',()=>{
 expect(source.schema).toBe('cd-v25-temporal-real-v1');
 expect(source.samples).toHaveLength(57);
 expect(source.frames).toHaveLength(19);
 expect(glb.lods).toHaveLength(3);
 const dispose=registerBuiltinRigOps();
 try{
 for(let lod=0;lod<3;lod++){
   const sk=glb.lods[lod].compiledHumanoidSkeleton;
   const world=originalWorldNodes(sk);
   const definition=autoRig(sk,{character:'cd-oss-v25',rig:'native-v25-'+lod},
     {kind:'humanoid',secondary:false});  // FK channels: plantFeetChannels solves real two-bone
   const program=compileRig(definition,sk);
   const lookup=new Map(sk.nodes.map((n:any)=>[n.name,n.index]));
   for(const sample of source.samples.filter((row:any)=>row.lod===lod)){
    for(const label of ['A','B']){
     const actor=sample.actors[label];
     expect(Object.keys(actor.bones)).toHaveLength(53);
     const names=['thigh_l','thigh_r','foot_l'];
     const g=names.map(n=>world.get(n));
     const b=names.map(n=>captured(actor.bones[n].restWorld));
     expect(g.every(Boolean)).toBe(true);
     const C=conversion(g,b),Ci=C.clone().invert();
     let maxRestError=0;
     for(const name of ['thigh_l','thigh_r','calf_l','calf_r','foot_l','foot_r']){
       const gg=world.get(name)!;
       const bb=captured(actor.bones[name].restWorld);
       maxRestError=Math.max(maxRestError,dist(C.clone().multiply(gg),bb));
     }
     expect(maxRestError).toBeLessThan(.015);
     const targetBones=new Map<number,number[]>();
     for(const [name,data] of Object.entries(actor.bones) as [string,any][]){
       const node=lookup.get(name);
       if(node===undefined)continue;
       targetBones.set(node as number,Ci.clone().multiply(captured(data.world)).toArray());
     }
     const ch=program.allocChannels(),pose=program.allocPose();
     program.evaluate(ch,pose);
     const values=solveBoneChannels(program,pose,targetBones,new Map());
     expect(values.size).toBeGreaterThan(10);
     for(const [ctrl,v] of values)writeControlChannels(program,ch,ctrl,v);
     program.evaluate(ch,pose);
     let maxReconstruction=0;
     for(const name of ['pelvis','thigh_l','calf_l','foot_l','thigh_r','calf_r','foot_r']){
       const n=lookup.get(name) as number;
       const target=native(targetBones.get(n)!);
       maxReconstruction=Math.max(maxReconstruction,
         dist(native(Array.from(pose.boneWorld.slice(n*16,n*16+16))),target));
     }
     expect(maxReconstruction).toBeLessThan(.015);
     const pins:any[]=[];
     for(const lock of actor.stanceLocks){
       if(lock.influence<.99)continue;
       const footBone=captured(actor.bones['foot_'+lock.side].world);
       const position=vec(captured(lock.authoredTargetWorld));
       footBone.setPosition(position);
       const pin=Ci.clone().multiply(footBone);
       pins.push({side:lock.side==='l'?'L':'R',footWorld:pin.toArray()});
     }
     const poseBefore=program.allocPose();
     program.evaluate(ch,poseBefore);
     if(pins.length){
       const plant=plantFeetChannels(program,poseBefore,pins,new Map(),ch);
       if(!plant.reached || plant.warnings.length){
         const diagnostics=pins.map(pin=>{
           const prefix=pin.side==='L'?'l':'r';
           const hipId=lookup.get('thigh_'+prefix) as number;
           const hip=native(Array.from(poseBefore.boneWorld.slice(hipId*16,hipId*16+16)));
           const knee=world.get('calf_'+prefix)!;
           const foot=world.get('foot_'+prefix)!;
           const upper=world.get('thigh_'+prefix)!;
           return {side:pin.side,
             sourcePinToHipM:dist(hip,native(pin.footWorld)),
             originalRigReachM:dist(upper,knee)+dist(knee,foot),
             pinWorldPosition:vec(native(pin.footWorld)).toArray(),
             hipPosition:vec(hip).toArray()};
         });
         const failure={lod,frame:sample.frame,actor:label,warnings:plant.warnings,
           realSourcePins:diagnostics,poseReconstructionErrorM:maxReconstruction,
           restFrameErrorM:maxRestError};
         result.errors.push(failure);
         result.status='STOP_V25_REAL_STANCE_PIN_UNREACHABLE';
         writeFileSync(process.env.CD_NATIVE_OUT!,JSON.stringify(result,null,2)+'\\n');
         console.error('REAL_V25_EKZA_PIN_UNREACHABLE',JSON.stringify(failure));
       }
       expect(plant.reached).toBe(true);
       expect(plant.warnings).toEqual([]);
       for(const [ctrl,v] of plant.values)writeControlChannels(program,ch,ctrl,v);
       program.evaluate(ch,pose);
     }
     let maxPinError=0;
     for(const pin of pins){
       const side=pin.side==='L'?'l':'r';
       const n=lookup.get('foot_'+side) as number;
       const actual=native(Array.from(pose.boneWorld.slice(n*16,n*16+16)));
       maxPinError=Math.max(maxPinError,dist(actual,native(pin.footWorld)));
     }
     expect(maxPinError).toBeLessThan(.008);
     const pelvisNode=lookup.get('pelvis') as number;
     const oldPelvis=native(Array.from(poseBefore.boneWorld.slice(pelvisNode*16,pelvisNode*16+16)));
     const newPelvis=native(Array.from(pose.boneWorld.slice(pelvisNode*16,pelvisNode*16+16)));
     expect(dist(oldPelvis,newPelvis)).toBeLessThan(.0001);
     const relevant:any={};
     for(const name of ['thigh_l','calf_l','foot_l','thigh_r','calf_r','foot_r']){
       const id=lookup.get(name) as number;
       relevant[name]=Array.from(pose.boneWorld.slice(id*16,id*16+16));
     }
     result.samples.push({lod,frame:sample.frame,actor:label,
       pins:pins.map(x=>({side:x.side,world:x.footWorld})),
       pinCount:pins.length,maxRestErrorM:maxRestError,
       maxOriginalPoseReconstructionErrorM:maxReconstruction,
       maxPinnedFootErrorM:maxPinError,
       originalActorRootWorld:actor.actorRootWorld,
       correctedLegBoneWorldGlTf:relevant});
    }
   }
 }
 expect(result.samples).toHaveLength(114);
 expect(new Set(result.samples.filter((x:any)=>x.pinCount).map((x:any)=>x.lod)).size).toBe(3);
 result.status='NATIVE_EKZA_SOURCE_V25_TRUE_PINS_NUMERIC_ONLY_NOT_VISUAL';
 writeFileSync(process.env.CD_NATIVE_OUT!,JSON.stringify(result,null,2)+'\n');
 } finally{dispose();}
});
