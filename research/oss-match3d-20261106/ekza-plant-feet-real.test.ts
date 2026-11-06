// Executes the ORIGINAL Ekza Studio autoRig -> compileRig -> plantFeetChannels chain.
// Skeleton nodes and rest TRS originate from the three locked original 53-bone body GLBs.
// The foot pins are synthetic nearby targets: NOT a gait/contact or Blender visual pass.
import {readFileSync,writeFileSync} from 'node:fs';
import {test,expect} from 'vitest';
import {autoRig,compileRig,registerBuiltinRigOps,plantFeetChannels,writeControlChannels,isHumanoidProgram} from '../src/index';

const input=JSON.parse(readFileSync(process.env.CD_REST_INPUT!, 'utf8'));
const rows:any[]=[];
function pos(m:ArrayLike<number>):number[]{return [m[12],m[13],m[14]];}
function error(a:number[],b:number[]):number {return Math.hypot(...a.map((x,i)=>x-b[i]));}
test('real plantFeetChannels with compiled 53-joint humanoid CD GLBs',()=>{
  expect(input.schema).toBe('cd-real-rest-trs-v1');
  expect(input.lods).toHaveLength(3);
  const dispose=registerBuiltinRigOps();
  try {
    for (const lod of input.lods) {
      expect(lod.rigBoneCount).toBe(53);
      const skeleton=lod.compiledHumanoidSkeleton;
      expect(skeleton.nodes.filter((n:any)=>n.isJoint)).toHaveLength(53);
      expect(skeleton.fingerprint).toBe('sha256:'+lod.originalGlbSha256);
      const def=autoRig(skeleton,
        {character:'cd-oss-rd-character',rig:'cd-oss-rig-'+lod.lod},
        {kind:'humanoid',ik:{legs:true,arms:false},secondary:false});
      const program=compileRig(def,skeleton);
      expect(isHumanoidProgram(program)).toBe(true);
      expect(program.limbs.map(l=>l.id)).toContain('leg.L');
      expect(program.limbs.map(l=>l.id)).toContain('leg.R');
      const channels=program.allocChannels();
      const pose=program.allocPose();
      program.evaluate(channels,pose);
      const pins=[];
      for(const side of ['L','R'] as const){
        const name=side==='L'?'left':'right';
        const footIdx=skeleton.humanoid[name+'Foot'];
        const hipIdx=skeleton.humanoid[name+'UpperLeg'];
        expect(Number.isInteger(footIdx)).toBe(true);
        const foot=Array.from(pose.boneWorld.slice(footIdx*16,footIdx*16+16));
        const hip=Array.from(pose.boneWorld.slice(hipIdx*16,hipIdx*16+16));
        const neutral=pos(foot),hipAt=pos(hip);
        const pin=[...foot];
        // Move the real rest foot 6% towards its original hip; reachable by design.
        for(let axis=0;axis<3;axis++) pin[12+axis]+=(hipAt[axis]-neutral[axis])*.06;
        pins.push({side,footWorld:pin,footIdx,hipIdx,original:neutral});
      }
      const result=plantFeetChannels(program,pose,
        pins.map(({side,footWorld})=>({side,footWorld})),new Map(),channels);
      expect(result.reached).toBe(true);
      expect(result.warnings).toEqual([]);
      expect(result.values.size).toBeGreaterThanOrEqual(2);
      for(const [control,values] of result.values)
        writeControlChannels(program,channels,control,values);
      const after=program.allocPose();
      program.evaluate(channels,after);
      for(const p of pins){
        const actual=pos(after.boneWorld.slice(p.footIdx*16,p.footIdx*16+16));
        const goal=pos(p.footWorld);
        const deviation=error(actual,goal);
        expect(Number.isFinite(deviation)).toBe(true);
        expect(deviation).toBeLessThan(.002);
        rows.push({lod:lod.lod,side:p.side,originalGlbSha256:lod.originalGlbSha256,
          actualFootWorld:actual,pinWorld:goal,pinPositionErrorMetres:deviation,
          usedOriginalEkzaPlantFeet:true,
          humanoidJointCount:skeleton.nodes.filter((n:any)=>n.isJoint).length,
          controlCount:program.controlIds.length,limbCount:program.limbs.length});
      }
    }
    expect(rows).toHaveLength(6);
    writeFileSync(process.env.CD_PLANT_REPORT!,JSON.stringify({
      status:'NATIVE_EKZA_PLANT_FEET_COMPILED_REAL_53_BONES_SYNTHETIC_PIN',
      upstreamPinnedSha:process.env.CD_EKZA_SHA,
      actualSourceCalls:['autoRig','compileRig','plantFeetChannels'],
      notes:'Original GLB rest TRS and humanoid mapping, synthetic nearby foot pins, no animation or Blender imagery.',
      results:rows},null,2)+'\n');
  } finally {dispose();}
});
