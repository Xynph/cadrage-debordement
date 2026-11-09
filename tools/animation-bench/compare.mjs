import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const revision = '218ce2adff35a7c04657768a85ff002ebd461c78';
const [checkout, output] = process.argv.slice(2);
if (!checkout || !output) {
  console.error('Usage: node tools/animation-bench/compare.mjs <prompt2rig-checkout> <new-output-directory>');
  process.exit(1);
}

const upstream = resolve(checkout);
const source = join(upstream, 'public', 'retarget.js');
const git = (...args) => execFileSync('git', ['-C', upstream, ...args], { encoding: 'utf8' }).trim();
assert.equal(git('rev-parse', 'HEAD'), revision, 'Version de prompt2rig différente de celle du banc');
assert.equal(git('hash-object', source), git('rev-parse', 'HEAD:public/retarget.js'), 'Module de retarget modifié');

const threeBuild = dirname(createRequire(pathToFileURL(source)).resolve('three'));
const THREE = await import(pathToFileURL(join(threeBuild, 'three.module.js')));
const threePackage = JSON.parse(await readFile(join(threeBuild, '..', 'package.json'), 'utf8'));
assert.equal(threePackage.version, '0.169.0', 'Version de Three.js différente de celle du navigateur prompt2rig');
const { mergeGeometries } = await import(pathToFileURL(join(threeBuild, '..', 'examples/jsm/utils/BufferGeometryUtils.js')));
const { GLTFExporter } = await import(pathToFileURL(join(threeBuild, '..', 'examples/jsm/exporters/GLTFExporter.js')));
const { Rig, Track, trackToClip } = await import(pathToFileURL(source));

// GLTFExporter uses the browser FileReader API to assemble binary buffers.
globalThis.FileReader ??= class {
  async readAsArrayBuffer(blob) {
    this.result = await blob.arrayBuffer();
    this.onloadend();
  }
};

const fps = 30;
const duration = 2;
const steps = fps * duration;
const sides = ['Left', 'Right'];
const forwardAxis = new THREE.Vector3(0, 0, 1);
const upAxis = new THREE.Vector3(0, 1, 0);
const toes = sides.map(side => `${side}ToeBase`);
const wrists = sides.map(side => `${side}Hand`);

function createFixture() {
  const model = new THREE.Group();
  model.name = 'celebration_fixture';
  const bones = {};
  const sizes = {};
  function bone(name, parent, position, size) {
    const joint = new THREE.Bone();
    joint.name = name;
    joint.position.fromArray(position);
    (bones[parent] ?? model).add(joint);
    bones[name] = joint;
    sizes[name] = size;
  }
  bone('Hips', null, [0, 0.91, 0], [0.29, 0.14, 0.15]);
  bone('Spine', 'Hips', [0, 0.14, 0], [0.29, 0.14, 0.15]);
  bone('Spine1', 'Spine', [0, 0.14, 0], [0.32, 0.14, 0.15]);
  bone('Spine2', 'Spine1', [0, 0.14, 0], [0.35, 0.14, 0.15]);
  bone('Neck', 'Spine2', [0, 0.14, 0], [0.09, 0.12, 0.1]);
  bone('Head', 'Neck', [0, 0.14, 0], [0.15, 0.16, 0.16]);
  for (const side of sides) {
    const x = side === 'Left' ? 1 : -1;
    bone(`${side}Shoulder`, 'Spine2', [x * 0.1, 0.06, 0], [0.16, 0.08, 0.09]);
    bone(`${side}Arm`, `${side}Shoulder`, [x * 0.11, 0, 0], [0.26, 0.09, 0.1]);
    bone(`${side}ForeArm`, `${side}Arm`, [x * 0.27, 0, 0], [0.24, 0.07, 0.08]);
    bone(`${side}Hand`, `${side}ForeArm`, [x * 0.24, 0, 0], [0.1, 0.05, 0.08]);
    bone(`${side}UpLeg`, 'Hips', [x * 0.1, -0.05, 0], [0.11, 0.43, 0.11]);
    bone(`${side}Leg`, `${side}UpLeg`, [0, -0.42, 0.025], [0.09, 0.4, 0.09]);
    bone(`${side}Foot`, `${side}Leg`, [0, -0.39, -0.025], [0.1, 0.1, 0.16]);
    bone(`${side}ToeBase`, `${side}Foot`, [0, -0.02, 0.12], [0.1, 0.06, 0.09]);
  }
  model.updateMatrixWorld(true);
  const joints = Object.values(bones);
  const parts = joints.map((joint, index) => {
    const [width, height, length] = sizes[joint.name];
    const center = joint.getWorldPosition(new THREE.Vector3());
    const child = joint.children.length === 1 && joint.children[0];
    if (child) center.lerp(child.getWorldPosition(new THREE.Vector3()), 0.5);
    const part = new THREE.BoxGeometry(width, height, length).translate(...center.toArray());
    const count = part.attributes.position.count;
    const indices = new Uint16Array(count * 4);
    const weights = new Float32Array(count * 4);
    for (let vertex = 0; vertex < count; vertex += 1) {
      indices[vertex * 4] = index;
      weights[vertex * 4] = 1;
    }
    part.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(indices, 4));
    part.setAttribute('skinWeight', new THREE.Float32BufferAttribute(weights, 4));
    return part;
  });
  const mesh = new THREE.SkinnedMesh(mergeGeometries(parts), new THREE.MeshStandardMaterial({ color: 0x4466aa }));
  mesh.name = 'fixture_mesh';
  mesh.add(bones.Hips);
  model.add(mesh);
  mesh.bind(new THREE.Skeleton(joints));
  return new Rig(model);
}

function poseAuthored(rig, t) {
  const lift = Math.sin(Math.PI * t / duration) ** 2;
  for (const side of sides) {
    const sign = side === 'Left' ? 1 : -1;
    rig.bones[`${side}Arm`].quaternion.setFromAxisAngle(forwardAxis, sign * (-0.95 + 1.9 * lift));
    rig.bones[`${side}ForeArm`].quaternion.setFromAxisAngle(upAxis, -sign * (0.2 + 0.65 * lift));
  }
  rig.model.updateMatrixWorld(true);
}

function worldPoint(rig, name) {
  return rig.bones[name].getWorldPosition(new THREE.Vector3());
}

function poseLandmarks(rig, t, withNoise) {
  const landmarks = Array.from({ length: 33 }, () => new THREE.Vector3());
  const visibility = new Float32Array(33);
  const hips = worldPoint(rig, 'Hips');
  const head = worldPoint(rig, 'Head');
  function set(index, point) {
    landmarks[index].copy(point).sub(hips);
    visibility[index] = 1;
  }
  set(2, head.clone().add(new THREE.Vector3(0.03, 0, 0.075)));
  set(5, head.clone().add(new THREE.Vector3(-0.03, 0, 0.075)));
  set(7, head.clone().add(new THREE.Vector3(0.08, 0, 0)));
  set(8, head.clone().add(new THREE.Vector3(-0.08, 0, 0)));
  sides.forEach((side, offset) => {
    for (const [index, joint] of [[11, 'Arm'], [13, 'ForeArm'], [15, 'Hand'], [23, 'UpLeg'],
      [25, 'Leg'], [27, 'Foot'], [31, 'ToeBase']]) {
      const point = worldPoint(rig, `${side}${joint}`);
      if (withNoise && (index === 27 || index === 31)) {
        point.x += 0.004 * Math.sin(2 * Math.PI * 2 * t + offset);
        point.z += 0.004 * Math.sin(2 * Math.PI * 3 * t + offset);
      }
      set(index + offset, point);
    }
  });
  return [landmarks, visibility];
}

function measure(rig, clip, reference = []) {
  const mixer = new THREE.AnimationMixer(rig.model);
  mixer.clipAction(clip).setLoop(THREE.LoopOnce, 1).play().clampWhenFinished = true;
  const frames = [];
  let footSlide = 0;
  let footHeight = 0;
  let wristExcursion = 0;
  let wristError = 0;
  let largestStep = 0;
  for (let index = 0; index <= steps; index += 1) {
    mixer.setTime(index / fps);
    rig.model.updateMatrixWorld(true);
    const feet = toes.map(name => worldPoint(rig, name));
    const hands = wrists.map(name => worldPoint(rig, name));
    const rotations = rig.order.map(name => rig.bones[name].getWorldQuaternion(new THREE.Quaternion()).normalize());
    const finite = [...feet, ...hands, ...rotations].every(value => value.toArray().every(Number.isFinite));
    assert.ok(finite, `Transformation non finie à l'image ${index}`);
    frames.push({ feet, hands, rotations });
    feet.forEach((foot, side) => {
      const first = frames[0].feet[side];
      footSlide = Math.max(footSlide, Math.hypot(foot.x - first.x, foot.z - first.z));
      footHeight = Math.max(footHeight, Math.abs(foot.y - first.y));
    });
    hands.forEach((hand, side) => {
      wristExcursion = Math.max(wristExcursion, hand.distanceTo(frames[0].hands[side]));
      if (reference.length) wristError = Math.max(wristError, hand.distanceTo(reference[index].hands[side]));
    });
    if (index > 0) {
      largestStep = Math.max(largestStep, ...rotations.map((rotation, joint) =>
        rotation.angleTo(frames[index - 1].rotations[joint])));
    }
  }
  const last = frames.at(-1);
  const first = frames[0];
  const seamAngle = Math.max(...last.rotations.map((rotation, joint) => rotation.angleTo(first.rotations[joint])));
  const firstPoints = [...first.feet, ...first.hands];
  const seamDistance = Math.max(...[...last.feet, ...last.hands].map((point, joint) =>
    point.distanceTo(firstPoints[joint])));
  const millimeters = meters => Number((meters * 1000).toFixed(3));
  const degrees = radians => Number(THREE.MathUtils.radToDeg(radians).toFixed(4));
  mixer.stopAllAction();
  rig.reset();
  return { frames, metrics: {
    finiteFrames: frames.length,
    maxFootSlideMm: millimeters(footSlide),
    maxFootHeightChangeMm: millimeters(footHeight),
    maxWristExcursionMm: millimeters(wristExcursion),
    maxWristErrorAgainstAuthoredMm: reference.length ? millimeters(wristError) : null,
    maxJointStepDeg: degrees(largestStep),
    maxLoopSeamDeg: degrees(seamAngle),
    maxLoopSeamMm: millimeters(seamDistance),
  } };
}

const methods = [
  { name: 'celebration_authored', rig: createFixture() },
  { name: 'celebration_retargeted_clean', rig: createFixture(), noise: false },
  { name: 'celebration_retargeted_noisy', rig: createFixture(), noise: true },
];
for (const method of methods) method.track = new Track(method.rig.order.length);
for (let frame = 0; frame <= steps; frame += 1) {
  const t = frame / fps;
  const authored = methods[0].rig;
  poseAuthored(authored, t);
  methods[0].track.push(t, authored.snapshot());
  for (const method of methods.slice(1)) {
    method.rig.reset();
    method.rig.applyLandmarks(...poseLandmarks(authored, t, method.noise));
    method.track.push(t, method.rig.snapshot());
  }
}

const directory = resolve(output);
await mkdir(directory);
let reference = [];
const results = [];
for (const { name, rig, track } of methods) {
  const clip = trackToClip(rig, track, name);
  const { frames, metrics } = measure(rig, clip, reference);
  if (!reference.length) reference = frames;
  assert.equal(metrics.finiteFrames, steps + 1);
  assert.ok(metrics.maxWristExcursionMm > 300, `${name}: geste des bras absent`);
  assert.ok(metrics.maxLoopSeamDeg < 0.01, `${name}: raccord de boucle discontinu`);
  assert.ok(metrics.maxLoopSeamMm < 0.01, `${name}: points de contact discontinus au raccord`);
  const glb = Buffer.from(await new GLTFExporter().parseAsync(rig.model, { animations: [clip], binary: true }));
  assert.equal(glb.toString('ascii', 0, 4), 'glTF');
  assert.equal(glb.readUInt32LE(4), 2);
  assert.equal(glb.readUInt32LE(8), glb.length);
  const asset = JSON.parse(glb.toString('utf8', 20, 20 + glb.readUInt32LE(12)));
  assert.equal(asset.animations[0].name, name);
  assert.equal(asset.animations[0].channels.length, clip.tracks.length);
  assert.equal(asset.skins[0].joints.length, rig.order.length);
  const filename = `${name}.glb`;
  assert.match(filename, /^[a-z0-9_]+\.glb$/);
  await writeFile(join(directory, filename), glb, { flag: 'wx' });
  results.push({ name, metrics, asset: {
    filename, format: 'GLB 2.0', bytes: glb.length, sha256: createHash('sha256').update(glb).digest('hex'),
    animationChannels: clip.tracks.length, joints: rig.order.length,
    triangles: rig.model.getObjectByName('fixture_mesh').geometry.index.count / 3,
  } });
}

assert.equal(results[0].metrics.maxFootSlideMm, 0);
assert.ok(results[2].metrics.maxFootSlideMm > results[1].metrics.maxFootSlideMm, 'La perturbation doit accroître la dérive');
const report = { prompt2rig: revision, three: threePackage.version, fps, durationSeconds: duration, results };
await writeFile(join(directory, 'report.json'), `${JSON.stringify(report, null, 2)}\n`, { flag: 'wx' });
console.table(results.map(({ name, metrics, asset }) => ({ name, ...metrics, bytes: asset.bytes })));
