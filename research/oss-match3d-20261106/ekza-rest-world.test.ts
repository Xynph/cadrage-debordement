// No imitation solver: call the unmodified upstream Ekza solveTwoBoneIk
// using ORIGINAL glTF rest TRS and world hierarchy (not artificial unit rest).
import {readFileSync,writeFileSync} from 'node:fs';
import {test,expect} from 'vitest';
import {solveTwoBoneIk} from '../src/ik/twoBone';
import {mat4Compose,xfMultiply,quatMultiply,quatRotateVec3} from '@ekza-studio/anim-core';

type Xf={t:[number,number,number],q:[number,number,number,number],s:[number,number,number]};
const source=JSON.parse(readFileSync(process.env.CD_REST_INPUT!, 'utf8'));
const identity:Xf={t:[0,0,0],q:[0,0,0,1],s:[1,1,1]};
const norm=(v:number[])=>Math.hypot(...v);
const minus=(a:number[],b:number[])=>a.map((v,i)=>v-b[i]);
const plus=(a:number[],b:number[])=>a.map((v,i)=>v+b[i]);
const mix=(a:number[],b:number[],weight:number)=>a.map((v,i)=>v+(b[i]-v)*weight);
const results:unknown[]=[];
test('true Ekza native solver with original GLB rest local TRS and parent world',()=>{
 expect(source.schema).toBe('cd-real-rest-trs-v1');
 expect(source.lods).toHaveLength(3);
 for(const lod of source.lods){
  expect(lod.rigBoneCount).toBe(53);
  expect(lod.originalGlbSha256).toMatch(/^[0-9a-f]{64}$/);
  for(const side of ['l','r'] as const){
   const ch=lod.sides[side];
   let parent:Xf=identity;
   for(const node of ch.ancestors) parent=xfMultiply(parent,node as Xf);
   const hip=xfMultiply(parent,ch.upper as Xf);
   const knee=xfMultiply(hip,ch.mid as Xf);
   const foot=xfMultiply(knee,ch.end as Xf);
   const l1=norm(minus(knee.t,hip.t)),l2=norm(minus(foot.t,knee.t));
   expect(l1).toBeGreaterThan(0.1);
   expect(l2).toBeGreaterThan(0.1);
   const target=mix(hip.t,foot.t,.90);
   const pole=plus(knee.t,[0,0,l1+l2]);
   const out={upperLocal:[0,0,0,1],midLocal:[0,0,0,1],endLocal:[0,0,0,1],reached:false};
   solveTwoBoneIk({
     parentWorld:mat4Compose(parent),
     upperRest:ch.upper,midRest:ch.mid,endRest:ch.end,
     hingeLocal:[1,0,0],target,pole,twist:0,soft:0,endWorldRotation:null
   },out);
   for(const q of [out.upperLocal,out.midLocal,out.endLocal]){
     expect(q.every(Number.isFinite)).toBe(true);
     expect(Math.abs(norm(q)-1)).toBeLessThan(.001);
   }
   // Reconstruct end location from real rest hierarchy and returned local quats.
   const upper=xfMultiply(parent,{...ch.upper,q:out.upperLocal});
   const mid=xfMultiply(upper,{...ch.mid,q:out.midLocal});
   const end=xfMultiply(mid,{...ch.end,q:out.endLocal});
   const error=norm(minus(end.t,target));
   expect(error).toBeLessThan(.003);
   expect(out.reached).toBe(true);
   results.push({lod:lod.lod,side,glbSha256:lod.originalGlbSha256,
      originalHip:hip.t,originalKnee:knee.t,originalFoot:foot.t,target,
      reached:out.reached,forwardPositionErrorMetres:error,
      localQuaternions:{thigh:out.upperLocal,calf:out.midLocal,foot:out.endLocal}});
  }
 }
 expect(results).toHaveLength(6);
 writeFileSync(process.env.CD_REST_OUTPUT!,JSON.stringify({
  schema:'cd-ekza-real-rest-v1',sourceExecutedDirectly:true,
  upstreamPinnedSha:process.env.CD_EKZA_SHA,method:'real glTF parent and rest TRS; synthetic nearby foot-pin target',
  results,limitation:'not Blender bone basis / skin evaluation; no plantFeetChannels RigProgram humanoid compiled'
 },null,2)+'\n');
});
