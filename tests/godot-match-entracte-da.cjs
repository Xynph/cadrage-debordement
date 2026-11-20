'use strict';
// Entracte du match, direction artistique du 19/11/2026 (variante 1, panneau d'arrêt de la 3, colonne Plaquages
// de la 2) : tests/godot-match-entracte-da.gd (Godot réel, sans moteur). Blocs à l'écran, boutons qui agissent sans
// fenêtre, aucun or, textes d'au moins 12 px, noms vers la fiche, panneau d'arrêt à droite, clavier.
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
test('Entracte (DA) : maquette, liens actifs sans fenêtre, aucun or, panneau d’arrêt, clavier', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 180000 }, () => {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-entracte-da.gd')], {
    env: { ...process.env, CD_GODOT_SELF_TEST: '0' }, encoding: 'utf8', windowsHide: true, timeout: 150000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-4000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
  assert.match(output, /MATCH_ENTRACTE_DA_CHECKS \d+ failures=0/);
});
