'use strict';
// Après-match (verdict en tête, classement complet) dans Godot réel, sans moteur : tests/godot-apres-match.gd.
// Données de fin de match (moteur seul) : tests/multiplex-direct.cjs, tests/match-pourquoi.cjs.
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;
test('Après-match : verdict, pourquoi, classement complet, liens et aucune fenêtre', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 180000 }, () => {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-apres-match.gd')], {
    env: { ...process.env, CD_GODOT_SELF_TEST: '0' }, encoding: 'utf8', windowsHide: true, timeout: 150000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-4000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
  assert.match(output, /Après-match Godot · \d+ contrôles réussis/);
});
