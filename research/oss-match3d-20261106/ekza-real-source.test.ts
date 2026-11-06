// Executes Ekza Studio's REAL solveTwoBoneIk imported from upstream workspace.
// This is a rig-dimension smoke test; no Blender skinning is claimed.
import { readFileSync, writeFileSync } from 'node:fs';
import { expect, test } from 'vitest';
import { solveTwoBoneIk } from '../src/ik/twoBone';

type Vec3 = [number, number, number];
const unit: [number,number,number,number] = [0,0,0,1];
const identityMat = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
const fixtures = JSON.parse(readFileSync(process.env.CD_RIG_FIXTURES!, 'utf8'));
const results: Array<Record<string, unknown>> = [];

test('actual Ekza Studio two-bone solver on all original CD 53-joint rig dimensions', () => {
  expect(fixtures.schema).toBe('cd-glb-53bone-ik-fixture-v1');
  expect(fixtures.lods).toHaveLength(3);
  const hashes: string[]=[];
  for (const lod of fixtures.lods) {
    expect(lod.jointCount).toBe(53);
    expect(new Set(lod.boneNames).size).toBe(53);
    expect(lod.orderedBoneNamesSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(lod.glbSha256).toMatch(/^[0-9a-f]{64}$/);
    hashes.push(lod.orderedBoneNamesSha256);
    for (const side of ['l','r'] as const) {
      const leg = lod.sides[side];
      expect(leg.names).toEqual(['thigh_'+side,'calf_'+side,'foot_'+side]);
      const l1=leg.upperLengthM as number, l2=leg.lowerLengthM as number;
      const reach=l1+l2;
      const target: Vec3=[0,-reach*0.8,0.06];
      const output={upperLocal:[...unit],midLocal:[...unit],endLocal:[...unit],reached:false};
      solveTwoBoneIk({
        parentWorld: identityMat,
        upperRest:{t:[0,0,0],q:unit,s:[1,1,1]},
        midRest:{t:[0,-l1,0],q:unit,s:[1,1,1]},
        endRest:{t:[0,-l2,0],q:unit,s:[1,1,1]},
        hingeLocal:[1,0,0],
        target,pole:[0,-reach*.4,1],twist:0,soft:0,endWorldRotation:null
      },output);
      expect(output.reached).toBe(true);
      for(const q of [output.upperLocal,output.midLocal,output.endLocal]){
        expect(q.every(Number.isFinite)).toBe(true);
        expect(Math.abs(q.reduce((a,b)=>a+b*b,0)-1)).toBeLessThan(0.001);
      }
      results.push({lod:lod.lod,side,realRig53:true,originalGlbSha256:lod.glbSha256,
        upperLengthM:l1,lowerLengthM:l2,target,reached:output.reached,
        upperLocal:output.upperLocal,midLocal:output.midLocal,endLocal:output.endLocal});
    }
  }
  expect(new Set(hashes).size).toBe(1);
  expect(results).toHaveLength(6);
  writeFileSync(process.env.CD_EKZA_REPORT!,JSON.stringify({
    status:'NATIVE_EKZA_SOLVER_RIG_DIMENSIONS_ONLY',upstreamPinnedSha:process.env.CD_EKZA_SHA,
    sourcePath:'packages/rig/src/ik/twoBone.ts',sourceExecutedDirectly:true,
    sourceGlbCount:3,sourceJointsPerGlb:53,results,
    limitations:'Canonical synthetic target/rest quaternions; no original rig pose, skinning, Blender, or plantFeetChannels integration.'
  },null,2)+'\n');
});
