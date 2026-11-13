'use strict';
// Panneau d’attente et réponses différentielles : Godot réel + worker réel.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { createEncoder } = require('../native/engine/model-delta.cjs');

test('Réponses différentielles : reconstruction exacte, ordre des clés compris', () => {
  const encoder = createEncoder();
  let base = null, revision = -1;
  const models = [
    { a: 1, meta: { x: 1, y: [1, 2] }, clubLife: { p: { q: 1 } }, z: null },
    { a: 1, meta: { x: 2, y: [1, 2] }, clubLife: { p: { q: 1 } }, z: null },
    { meta: { y: [1, 2], w: 3 }, a: 2, clubLife: null, z: { k: 1 } },
    { meta: { y: [1, 2], w: 3 }, a: 2, clubLife: { n: 1 }, z: { k: 1 } },
  ];
  for (const model of models) {
    const line = encoder.encode({ id: 1, ok: true, model }, revision);
    const reply = JSON.parse(line);
    assert.equal(reply.model, undefined);
    base = encoder.apply(base, reply.patch);
    revision = reply.patch.rev;
    assert.equal(JSON.stringify(base), JSON.stringify(model));
  }
  const unchanged = JSON.parse(encoder.encode({ id: 2, ok: true, model: models.at(-1) }, revision));
  assert.deepEqual(unchanged.patch.set, {}, 'Rien de modifié : rien de renvoyé');
  assert.equal(JSON.parse(encoder.encode({ id: 3, ok: true, model: { a: 1 } }, 12345)).patch.full, true, 'Révision inconnue : réponse complète');
  assert.equal(encoder.encode({ id: null, ok: false, model: null, error: 'x' }, revision), '{"id":null,"ok":false,"model":null,"error":"x"}');
});

test('Panneau d’attente : absent sous 500 ms, présent pour une attente longue', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent',
}, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-chargement-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
    '--script', path.resolve(__dirname, 'godot-chargement.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 240000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
