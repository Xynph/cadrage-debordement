'use strict';
// Règle de Léo (21/11/2026) : chaque tuile ou pastille (Bureau, Effectif, Préparation) ouvre un écran ; vrai clic,
// vrai moteur, carrière Monde.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Tuiles et pastilles du lot phrases : chaque repère ouvre son écran', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-reperes-cliquables-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-reperes-cliquables.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 420000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /REPERES|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
