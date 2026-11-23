'use strict';
// Tactique › Phases arrêtées en combinaisons (idée FM27 n° 21, choix B de Léo du 23/11/2026) : combinaisons
// enregistrées à gauche, schéma au centre, étapes à droite ; touche, mêlée, pénalité, renvoi, attaque et défense ;
// un clic sur une combinaison ou un choix l'applique (aucun bouton Valider) ; plus de pastille « Moteur ».
// Carrière Monde créée ici. CD_COMBI_CAPTURES=<dossier> (+ CD_COMBI_TAILLE=LxH) : captures final-*.png.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

function preparer(sortie) {
  const jeu = M.ouvrir({ testVm: true });
  try {
    M.creer(jeu, 102);
    fs.writeFileSync(sortie, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

test('Phases arrêtées en combinaisons (carrière Monde)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-combinaisons-'));
  const exportPath = path.join(profile, 'carriere.json');
  preparer(exportPath);
  const captures = process.env.CD_COMBI_CAPTURES;
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(captures ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-combinaisons.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(profile, 'donnees'), CD_COMBI_EXPORT: exportPath },
    encoding: 'utf8', windowsHide: true, timeout: 300000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /COMBINAISONS|FAIL|ERROR|DEBUG/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.match(output, /COMBINAISONS \d+ controles, 0 echec/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
