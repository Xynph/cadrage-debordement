'use strict';
// Écran Composition (choix de Léo du 19/11/2026 : variante 1 « Terrain au centre, candidats dessous » + encart
// « Première ligne formée ») : interface Godot réelle + worker réel, carrière Monde. Tout ce qui a l'air cliquable agit,
// aucune fenêtre, aucune couleur or, clavier Espace prendre / poser, nom = fiche, survol = mini-fiche, sous-pages.
// CD_COMPOSITION_OUTPUT=<dossier> avec un affichage graphique : captures 1920 et 1280.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Composition : variante 1, candidats dessous, première ligne, sans fenêtre (carrière Monde)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-composition-'));
  const graphique = Boolean(process.env.CD_COMPOSITION_OUTPUT);
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(graphique ? ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-composition.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile },
    encoding: 'utf8', windowsHide: true, timeout: 420000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /COMPOSITION|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
