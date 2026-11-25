'use strict';
// Export compressé (exportVersion 4) : contrôle d'import de Godot (tests/godot-import-compresse.gd), sans moteur.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;

test('Godot : une enveloppe compressée passe le contrôle d\'import jusqu\'à 24 Mio, les autres refus sont inchangés', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 240000 }, () => {
  const r = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-import-compresse.gd')], {
    env: { ...process.env, CD_GODOT_SELF_TEST: '0' }, encoding: 'utf8', windowsHide: true, timeout: 200000,
  });
  const journal = (r.stdout || '') + (r.stderr || '');
  if (r.error) throw r.error;
  assert.equal(r.status, 0, journal.slice(-4000));
  assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/);
  assert.match(journal, /Import compressé Godot · \d+ contrôles réussis/);
});
