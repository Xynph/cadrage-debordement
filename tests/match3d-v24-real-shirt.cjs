'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),{auditGLB}=require('../tools/match3d-v24-glb-audit.cjs');
const dir='dist/match3d/assets/rugby-v24/lod';
for(let lod=0;lod<3;lod++){
 const data=fs.readFileSync(`${dir}/clothing_tshirt-lod${lod}.glb`),audit=auditGLB(data);assert.equal(audit.joints,53);
 const len=data.readUInt32LE(12),j=JSON.parse(data.subarray(20,20+len).toString()),bin=data.subarray(28+len);
 const mesh=j.meshes[0],p=mesh.primitives[0],pos=j.accessors[p.attributes.POSITION];
 assert.ok(mesh.extras.cdAthleticFit);assert.equal(p.targets?.length||0,0,'no second morph bake');
 for(const s of ['NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'])assert.equal(j.accessors[p.attributes[s]].count,pos.count,s+' vertex count');
 const access=index=>{const a=j.accessors[index],v=j.bufferViews[a.bufferView];return {a,v,offset:(v.byteOffset||0)+(a.byteOffset||0)};};
 const weights=access(p.attributes.WEIGHTS_0);assert.equal(weights.a.componentType,5126);
 for(let i=0;i<pos.count;i++){let sum=0;for(let k=0;k<4;k++){const w=bin.readFloatLE(weights.offset+i*(weights.v.byteStride||16)+k*4);assert.ok(Number.isFinite(w)&&w>=0&&w<=1);sum+=w;}assert.ok(Math.abs(sum-1)<1e-5,'weights sum to one');}
 console.log('PASS real shirt LOD'+lod+': '+audit.triangles+' triangles, 53 joints, UV/normals/weights, athletic bake');
}
