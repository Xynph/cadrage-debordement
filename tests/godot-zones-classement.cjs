'use strict';
// Zones de classement Monde dans le vrai écran Compétitions (tests/godot-zones-classement.gd) : liseré,
// symbole dessiné, libellé accessible, légende, note et ligne « Champion » sans chevauchement.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

test('Zones de classement Monde : liseré, symbole, mot et légende', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, () => {
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.join(__dirname, 'godot-zones-classement.gd'),
  ], { encoding: 'utf8', timeout: 60000, windowsHide: true, env: { ...process.env, CD_GODOT_SELF_TEST: '0' } });
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
  assert.match(output, /ZONES CLASSEMENT : [1-9][0-9]* contrôles ; 0 échec/);
});
