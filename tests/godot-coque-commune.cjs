'use strict';
// Coque commune (rail + barre haute, nouvelle direction artistique) : interface Godot réelle + worker réel, carrière Monde.
//   Ordre du rail, aucun numéro, tout est cliquable (rail, fil d'Ariane), Ctrl+K / Réglages / Sauvegarder sans fenêtre,
//   un seul aplat or (Continuer), recomposition à 1280×720, 1920×1080 et 2560×1440.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Coque commune de la carrière Monde', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-coque-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-coque-commune.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 420000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /COQUE|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
