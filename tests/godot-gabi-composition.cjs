'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;

test('Gabi : réaction de composition silencieuse et respect de la parole', {
  skip: !godot && 'SDK Godot requis pour la réception du portrait',
}, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gabi-composition-'));
  const result = spawnSync(godot, [
    '--headless', '--path', path.resolve(__dirname, '../native/godot'),
    '--log-file', path.join(directory, 'godot.log'),
    '--script', path.resolve(__dirname, 'godot-gabi-composition.gd'),
  ], {
    encoding: 'utf8',
    timeout: 30000,
    windowsHide: true,
    env: { ...process.env, APPDATA: directory, LOCALAPPDATA: directory },
  });
  const log = (result.stdout || '') + (result.stderr || '');
  console.log(log.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error|ERROR:/);
});
