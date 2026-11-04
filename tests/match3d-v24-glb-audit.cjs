'use strict';
const assert = require('node:assert/strict');
const { auditGLB } = require('../tools/match3d-v24-glb-audit.cjs');
function glb(doc) {
  const b = Buffer.from(JSON.stringify(doc)), pad = (4-b.length%4)%4;
  const chunk = Buffer.concat([b, Buffer.alloc(pad, 32)]);
  const head = Buffer.alloc(20);head.write('glTF', 0);head.writeUInt32LE(2,4);head.writeUInt32LE(20+chunk.length,8);head.writeUInt32LE(chunk.length,12);head.writeUInt32LE(0x4e4f534a,16);
  return Buffer.concat([head,chunk]);
}
const fixture = () => ({
  asset:{version:'2.0'}, skins:[{joints:Array.from({length:25},(_,i)=>i)}],
  nodes:[{mesh:0,skin:0}], meshes:[{primitives:[{attributes:{POSITION:0,JOINTS_0:1,WEIGHTS_0:2},indices:3}]}],
  accessors:[{count:90},{count:90},{count:90},{count:90}],materials:[{name:'shirt'}],
  animations:[{name:'run'}]
});
const ok = auditGLB(glb(fixture()),{maxTriangles:30});
assert.equal(ok.triangles,30);
assert.equal(ok.joints,25);
assert.equal(ok.animations[0],'run');
assert.equal(ok.selfContained,true);
assert.throws(()=>auditGLB(glb({...fixture(),skins:[]})),/Missing skinned rig/);
assert.throws(()=>auditGLB(glb({...fixture(),images:[{uri:'https:\/\/example.com\/texture.png'}]})),/forbidden/);
assert.throws(()=>auditGLB(glb({...fixture(),buffers:[{uri:'texture.bin'}]})),/External resource/);
assert.throws(()=>auditGLB(glb(fixture()),{maxTriangles:29}),/Triangle budget/);
assert.throws(()=>auditGLB(glb({...fixture(),animations:[]}),{requireAnimations:true}),/No animation clips/);
assert.throws(()=>auditGLB(Buffer.from('garbage')),/truncated|GLB magic/i);
console.log('MATCH 3D v24 GLB audit: 8 checks PASS (synthetic fixtures only; real assets NOT tested)');
