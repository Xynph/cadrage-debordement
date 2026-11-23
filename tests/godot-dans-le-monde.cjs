'use strict';
// Page « Dans le monde » (Compétitions, idée FM27 n° 30) dans le vrai écran (tests/godot-dans-le-monde.gd) : 16 thèmes ×
// 6 images de la banque des actus, page sans image manquante ni image en double, articles signés (journaliste + média du
// jeu), carte « Dernière minute », rotation des images d'un jour à l'autre, clics (affiche, vignette, article → petite
// fenêtre → club, rencontre ou classement), à 2560 × 1440 et 1920 × 1080.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

test('Dans le monde : images des actus, articles signés, clics', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, () => {
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.join(__dirname, 'godot-dans-le-monde.gd'),
  ], { encoding: 'utf8', timeout: 240000, windowsHide: true, env: { ...process.env, CD_GODOT_SELF_TEST: '0' } });
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
  assert.match(output, /DANS LE MONDE : [1-9][0-9]* contrôles ; 0 échec/);
});
