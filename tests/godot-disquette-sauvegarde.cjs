'use strict';
// Disquette de sauvegarde en arrière-plan (décision de Léo, 16/11/2026) : pont « CD_EVENT » et indicateur seuls,
// sans moteur ni carrière (tests/godot-disquette-sauvegarde.gd). Parcours complet avec le vrai moteur :
// tests/godot-ecrans-chargement.gd (Continuer) et tests/avance-jour-differe.cjs (événements persist).
// CD_DISQUETTE_CAPTURE=<dossier> : rendu fenêtré et captures PNG.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;
const capture = process.env.CD_DISQUETTE_CAPTURE;

test('Disquette de sauvegarde : délai, minimum, échec en rouge, jamais bloquante', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 300000 }, () => {
  const display = capture ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless'];
  const r = spawnSync(godot, [...display, '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-disquette-sauvegarde.gd')], {
    env: { ...process.env, CD_GODOT_SELF_TEST: '0' }, encoding: 'utf8', windowsHide: true, timeout: 240000,
  });
  const journal = (r.stdout || '') + (r.stderr || '');
  if (r.error) throw r.error;
  assert.equal(r.status, 0, journal.slice(-4000));
  assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/);
  assert.match(journal, /Disquette de sauvegarde Godot · \d+ contrôles réussis/);
});
