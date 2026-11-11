'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE;

test('Sélections et Réception : filtres, pagination et courrier vers la bonne fiche hôte', {
  skip: !godot && 'SDK Godot requis',
}, () => {
  const output = process.env.CD_INTERNATIONAL_UI_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'oval-international-ui-'));
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-international-profile-'));
  fs.mkdirSync(output, { recursive: true });
  const graphics = process.env.CD_INTERNATIONAL_UI_GRAPHICS === '1';
  const dimensions = process.env.QA_RESOLUTION || '1920x1080';
  assert.match(dimensions, /^(1920x1080|2560x1440)$/);
  const result = spawnSync(godot, [
    ...(graphics ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', dimensions] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '60', '--path', 'native/godot',
    '--log-file', path.join(output, 'engine.log'),
    '--script', path.resolve(__dirname, 'godot-international-reception.gd'),
  ], {
    cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 150000,
    env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1',
      CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profile,
      QA_RESOLUTION: dimensions, QA_OUTPUT: output },
  });
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(output, 'godot.log'), log);
  console.log(log.trim());
  console.log('Preuves Réception internationale : ' + output);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8')).failures, []);
});
