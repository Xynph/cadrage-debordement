'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tool = path.join(root, 'tools/animation-pipeline/inventory.py');
const source = path.join(root, 'dist/match3d/assets/quaternius-rugby-athlete.glb');
const reference = JSON.parse(fs.readFileSync(path.join(root, 'tools/animation-pipeline/inventory-baseline.json')));
const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
function run(...args) {
  return spawnSync(python, [tool, ...args], { encoding: 'utf8', timeout: 30000, maxBuffer: 2 * 1024 * 1024 });
}
function fixture(change) {
  const original = fs.readFileSync(source);
  const jsonLength = original.readUInt32LE(12);
  const doc = JSON.parse(original.subarray(20, 20 + jsonLength).toString());
  const binOffset = 20 + jsonLength;
  const bin = Buffer.from(original.subarray(binOffset + 8));
  change(doc, bin);
  let json = Buffer.from(JSON.stringify(doc));
  json = Buffer.concat([json, Buffer.alloc((4 - json.length % 4) % 4, 0x20)]);
  const header = Buffer.alloc(20);
  header.write('glTF'); header.writeUInt32LE(2, 4);
  header.writeUInt32LE(28 + json.length + bin.length, 8);
  header.writeUInt32LE(json.length, 12); header.writeUInt32LE(0x4e4f534a, 16);
  const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length); bh.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([header, json, bh, bin]);
}
function temporary(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-animation-inventory-'));
  try { return fn(dir); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('vrai athlète : inventaire reproductible sans modification et sans boucle inventée', () => {
  const before = fs.readFileSync(source);
  const result = run(source);
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  const report = JSON.parse(result.stdout);
  assert.deepEqual(report, reference);
  assert.equal(report.joint_count, 31);
  assert.equal(report.animation_count, 11);
  assert.equal(new Set(report.skins[0].joint_names).size, 31);
  assert(report.animations.every(a => a.duration_seconds > 0 && a.track_count > 0 && a.loop === 'not_defined_by_gltf'));
  assert.deepEqual(fs.readFileSync(source), before);
});

test('temps réels BIN : ne pas faire confiance au max déclaratif de l’accessor', () => temporary(dir => {
  const file = path.join(dir, 'false-metadata.glb');
  fs.writeFileSync(file, fixture(doc => { doc.accessors[doc.animations[0].samplers[0].input].max = [99999]; }));
  const result = run(file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).animations[0].duration_seconds, reference.animations[0].duration_seconds);
}));

test('fichiers tronqués, signature et longueurs incohérentes refusés sans toucher une sortie existante', () => temporary(dir => {
  const output = path.join(dir, 'report.json');
  const before = fs.readFileSync(source);
  const badMagic = Buffer.from(before); badMagic[0] = 0;
  const badLength = Buffer.from(before); badLength.writeUInt32LE(before.length - 4, 8);
  for (const bytes of [before.subarray(0, 10), before.subarray(0, before.length - 4), badMagic, badLength]) {
    const file = path.join(dir, 'broken.glb'); fs.writeFileSync(file, bytes);
    fs.writeFileSync(output, 'rapport précédent');
    const result = run(file, '--output', output);
    assert.equal(result.status, 2, result.stderr);
    assert.equal(JSON.parse(result.stderr).ok, false);
    assert.equal(result.stdout, '');
    assert.equal(fs.readFileSync(output, 'utf8'), 'rapport précédent');
  }
}));

test('références, bornes et données d’animation invalides sont refusées', () => temporary(dir => {
  const cases = [
    ['joint absent', d => { d.skins[0].joints[0] = d.nodes.length; }],
    ['joint négatif', d => { d.skins[0].joints[0] = -1; }],
    ['sampler absent', d => { d.animations[0].channels[0].sampler = 99999; }],
    ['cible absente', d => { d.animations[0].channels[0].target.node = 99999; }],
    ['accessor absent', d => { d.animations[0].samplers[0].input = 99999; }],
    ['vue débordante', d => { d.bufferViews[0].byteLength = 0x7fffffff; }],
    ['accessor débordant', d => { d.accessors[0].count = 0x7fffffff; }],
    ['compte clés incohérent', d => { d.accessors[d.animations[0].samplers[0].output].count -= 1; }],
    ['sparse non supporté', d => { d.accessors[0].sparse = {}; }],
    ['buffer externe interdit', d => { d.buffers[0].uri = 'https://example.invalid/asset.bin'; }],
    ['sortie animation NaN', (d, b) => {
      const a = d.accessors[d.animations[0].samplers[0].output]; const v = d.bufferViews[a.bufferView];
      b.writeFloatLE(NaN, (v.byteOffset || 0) + (a.byteOffset || 0));
    }],
    ['temps NaN', (d, b) => {
      const a = d.accessors[d.animations[0].samplers[0].input]; const v = d.bufferViews[a.bufferView];
      b.writeFloatLE(NaN, (v.byteOffset || 0) + (a.byteOffset || 0));
    }],
    ['temps dupliqué', (d, b) => {
      const a = d.accessors[d.animations[0].samplers[0].input]; const v = d.bufferViews[a.bufferView];
      const start = (v.byteOffset || 0) + (a.byteOffset || 0); b.copy(b, start + 4, start, start + 4);
    }],
  ];
  for (const [label, mutation] of cases) {
    const file = path.join(dir, 'invalid.glb'); fs.writeFileSync(file, fixture(mutation));
    const result = run(file);
    assert.equal(result.status, 2, label + ': ' + result.stderr);
    assert.equal(JSON.parse(result.stderr).ok, false, label);
    assert.equal(result.stdout, '', label);
  }
}));

test('erreurs disque visibles et refus de remplacer la source', () => temporary(dir => {
  const before = fs.readFileSync(source);
  const result = run(source, '--output', source);
  assert.equal(result.status, 2);
  assert.deepEqual(fs.readFileSync(source), before);
  const absent = run(path.join(dir, 'absent.glb'));
  assert.equal(absent.status, 2);
  const output = run(source, '--output', path.join(dir, 'absent', 'inventory.json'));
  assert.equal(output.status, 2);
  assert.equal(fs.existsSync(path.join(dir, 'absent')), false);
  assert.deepEqual(fs.readdirSync(dir), []);
}));

test('sortie JSON atomique égale à la référence, sans fichier temporaire restant', () => temporary(dir => {
  const output = path.join(dir, 'inventory.json');
  const result = run(source, '--output', output);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '');
  assert.deepEqual(JSON.parse(fs.readFileSync(output)), reference);
  assert.deepEqual(fs.readdirSync(dir), ['inventory.json']);
}));

test('liens physiques ou symboliques ne peuvent remplacer l’asset source', () => temporary(dir => {
  const localSource = path.join(dir, 'asset.glb');
  const original = fs.readFileSync(source); fs.writeFileSync(localSource, original);
  const alias = path.join(dir, 'hardlink.glb'); fs.linkSync(localSource, alias);
  assert.equal(run(localSource, '--output', alias).status, 2);
  assert.deepEqual(fs.readFileSync(localSource), original);
  assert.deepEqual(fs.readFileSync(alias), original);
  // Les symlinks ne sont pas disponibles sans privilège sur certains Windows.
  if (process.platform !== 'win32') {
    const symbolic = path.join(dir, 'symbolic.glb'); fs.symlinkSync(localSource, symbolic);
    assert.equal(run(localSource, '--output', symbolic).status, 2);
    assert.deepEqual(fs.readFileSync(symbolic), original);
  }
}));

test('JSON avec exposant débordant : erreur structurée sans traceback ni sortie partielle', () => temporary(dir => {
  const bytes = fixture(d => { d.asset.extra = 'OVERFLOW'; });
  const marker = bytes.indexOf(Buffer.from('"OVERFLOW"'));
  assert(marker >= 0); bytes.write('1e999     ', marker, 'ascii');
  const file = path.join(dir, 'overflow.glb'); fs.writeFileSync(file, bytes);
  const result = run(file);
  assert.equal(result.status, 2);
  assert.equal(JSON.parse(result.stderr).ok, false);
  assert.equal(result.stdout, '');
  assert(!result.stderr.includes('Traceback'));
}));
