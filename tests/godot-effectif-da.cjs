'use strict';
// Écran Effectif de la revue DA du 19/11/2026 : tuiles, équilibre par poste, puces, onglets, tableau, aucun or, aucune fenêtre.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Écran Effectif de la revue DA (carrière Monde)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-effectif-da-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-effectif-da.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 300000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /EFFECTIF DA|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
