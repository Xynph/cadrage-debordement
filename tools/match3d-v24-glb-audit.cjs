'use strict';
// Standalone gate for third-party glTF 2.0 binaries. No download or network use.
// A successful structural check does NOT certify aesthetics, legal rights or rugby animations.
const fs = require('node:fs');
const assert = require('node:assert/strict');

function auditGLB(buffer, options = {}) {
  assert(Buffer.isBuffer(buffer), 'GLB must be a Buffer');
  assert(buffer.length >= 20, 'GLB is truncated');
  assert.equal(buffer.toString('ascii', 0, 4), 'glTF', 'GLB magic');
  assert.equal(buffer.readUInt32LE(4), 2, 'GLB version 2 required');
  assert.equal(buffer.readUInt32LE(8), buffer.length, 'GLB declared length mismatch');
  let offset = 12, json = null, binSize = 0;
  while (offset < buffer.length) {
    assert(offset + 8 <= buffer.length, 'Truncated chunk header');
    const len = buffer.readUInt32LE(offset), type = buffer.readUInt32LE(offset + 4);
    offset += 8;
    assert(offset + len <= buffer.length, 'Truncated chunk');
    if (type === 0x4e4f534a) {
      assert(json === null, 'Duplicate JSON chunk');
      json = JSON.parse(buffer.subarray(offset, offset + len).toString('utf8').replace(/\0+$/g, ''));
    } else if (type === 0x004e4942) binSize += len;
    offset += len;
  }
  assert(json && json.asset && json.asset.version === '2.0', 'Missing glTF 2.0 JSON');
  const skins = json.skins || [], meshes = json.meshes || [], nodes = json.nodes || [];
  const animations = json.animations || [], accessors = json.accessors || [];
  assert(skins.length > 0, 'Missing skinned rig');
  assert(skins.some(s => Array.isArray(s.joints) && s.joints.length >= 20), 'Humanoid requires >=20 joints');
  assert(nodes.some(n => Number.isInteger(n.skin) && Number.isInteger(n.mesh)), 'No skin bound to mesh');
  assert(meshes.length > 0, 'No meshes');
  const primitives = meshes.flatMap(m => m.primitives || []);
  assert(primitives.some(p => p.attributes && Number.isInteger(p.attributes.JOINTS_0) && Number.isInteger(p.attributes.WEIGHTS_0)), 'Missing vertex skin weights');
  for (const uri of [...(json.buffers || []), ...(json.images || [])].map(x => x.uri).filter(Boolean)) {
    assert(!/^(https?:|data:|\/\/)/i.test(uri), 'External or embedded URI is forbidden: ' + uri.slice(0, 80));
    assert(!uri.includes('..') && !uri.startsWith('/'), 'Unsafe dependent asset path');
    throw new Error('External resource dependency: require self-contained GLB');
  }
  const materials = json.materials || [];
  let triangles = 0, unknownPrimitives = 0;
  for (const p of primitives) {
    if (p.mode !== undefined && p.mode !== 4) { unknownPrimitives++; continue; }
    const a = accessors[p.indices ?? p.attributes?.POSITION];
    if (!a || !Number.isInteger(a.count)) { unknownPrimitives++; continue; }
    triangles += Math.floor(a.count / 3);
  }
  assert.equal(unknownPrimitives, 0, 'Unknown primitive topology/count');
  const maxTriangles = options.maxTriangles;
  if (Number.isFinite(maxTriangles)) assert(triangles <= maxTriangles, 'Triangle budget exceeded');
  if (options.requireAnimations) assert(animations.length > 0, 'No animation clips');
  const clipNames = animations.map(a => a.name || '(unnamed)');
  return { bytes: buffer.length, triangles, meshes: meshes.length, materials: materials.length, skins: skins.length, joints: Math.max(...skins.map(s => s.joints?.length || 0)), animations: clipNames, embeddedBinaryBytes: binSize, selfContained: true };
}
module.exports = { auditGLB };
if (require.main === module) {
  const file = process.argv[2];
  if (!file) { console.error('Usage: node tools/match3d-v24-glb-audit.cjs <offline.glb> [maxTriangles]'); process.exit(2); }
  try {
    const maxTriangles = process.argv[3] ? Number(process.argv[3]) : undefined;
    console.log(JSON.stringify(auditGLB(fs.readFileSync(file), {maxTriangles}), null, 2));
  } catch (error) { console.error('GLB rejected:', error.message); process.exitCode = 1; }
}
