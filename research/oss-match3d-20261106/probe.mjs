// Isolated MIT dependency experiment. NOT a game integration or an anatomical certification.
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { MeshBVH } from 'three-mesh-bvh';

const lodSegments = [4, 2, 1];
const results = [];
function qualifiesSkin(mesh) {
  // Fixtures explicitly distinguish anatomy from technical overlap markers.
  return mesh.userData.skinned === true && mesh.userData.auxiliary !== true;
}
function querySkinCrossing(body, candidate) {
  if (!qualifiesSkin(body) || !qualifiesSkin(candidate)) return false;
  const tree = new MeshBVH(body.geometry, { indirect: true });
  body.updateMatrixWorld(true);
  candidate.updateMatrixWorld(true);
  const relative = body.matrixWorld.clone().invert().multiply(candidate.matrixWorld);
  return tree.intersectsGeometry(candidate.geometry, relative);
}
for (const [lod, segments] of lodSegments.entries()) {
  const box = () => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1, segments, segments, segments));
    m.userData.skinned = true; // proxy tag ONLY, not a SkinnedMesh
    return m;
  };
  const body = box();
  const disjoint = box(); disjoint.position.set(3, 0, 0);
  const crossing = box(); crossing.position.set(0.75, 0, 0);
  const helper = box(); helper.userData = { skinned: false, auxiliary: true };
  assert.equal(querySkinCrossing(body, disjoint), false, 'disjoint proxies must not intersect');
  assert.equal(querySkinCrossing(body, crossing), true, 'crossing proxies must intersect');
  assert.equal(querySkinCrossing(body, helper), false, 'auxiliary markers must be excluded');
  results.push({ lod, triangleCount: body.geometry.index.count / 3, disjoint: false, crossing: true, helperExcluded: true });
  for (const mesh of [body, disjoint, crossing, helper]) mesh.geometry.dispose();
}
assert.equal(results.length, 3);
console.log(JSON.stringify({ status: 'PASS_STATIC_PROXY_ONLY', libraries: { three: '0.185.0', bvh: '0.9.18' }, results }, null, 2));
