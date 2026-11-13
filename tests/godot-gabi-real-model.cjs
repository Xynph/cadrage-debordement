'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE;

test('Gabi livré : rig réel, six clips, F1, silence et mouvements réduits', {
  skip: !godot && 'SDK Godot requis',
}, () => {
  const output = process.env.CD_GABI_REAL_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'oval-gabi-real-'));
  fs.mkdirSync(output, { recursive: true });
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-gabi-profile-'));
  const graphics = process.env.CD_GABI_REAL_GRAPHICS === '1';
  const result = spawnSync(godot, [
    ...(graphics ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed'] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '60', '--path', 'native/godot',
    '--log-file', path.join(output, 'engine.log'),
    '--script', path.resolve(__dirname, 'godot-gabi-real-model.gd'),
  ], {
    cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: graphics ? 180000 : 120000,
    env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath,
      CD_GODOT_DATA_DIR: profile, CD_GABI_REAL_OUTPUT: output },
  });
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(output, 'godot.log'), log);
  console.log(log.trim());
  console.log('Preuves Gabi réel : ' + output);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8')).failures, []);
});
