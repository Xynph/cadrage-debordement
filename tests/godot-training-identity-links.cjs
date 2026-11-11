'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Entraînement : identité distincte des réglages, joueur et staff par ID', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent',
}, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-training-identity-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
    '--script', path.resolve(__dirname, 'godot-training-identity-links.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 180000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim());
  console.log('Preuves identité entraînement : ' + profile);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
