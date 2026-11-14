'use strict';
// Notes de match dans le vrai jeu Godot : effectif (moyenne, forme) et fiche joueur (moyenne,
// forme, historique, panneau « Sélection »). Le profil est une carrière Monde (`world-champ`) préparée par
// le vrai moteur : le calendrier avance jour par jour jusqu'au jour de chaque match, déjà délégué
// (tests/helpers/carriere-monde.cjs).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

function preparer(profil, matchs = 3) {
  const jeu = M.ouvrir({ dataDir: profil });
  try {
    const model = M.jouer(jeu, M.creer(jeu), matchs);
    jeu.call('save');
    return model;
  } finally { jeu.fermer(); }
}

test('Notes de match : effectif et fiche joueur dans le vrai jeu', { skip: !godot && 'SDK Godot requis' }, () => {
  const sortie = process.env.CD_NOTES_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-ui-'));
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-profil-'));
  fs.mkdirSync(sortie, { recursive: true });
  try {
    const model = preparer(profil, Number(process.env.CD_NOTES_MATCHS || 3));
    assert.ok(Object.keys(model.clubLife.matchNotes.joueurs).length >= 15, 'notes préparées');
    const graphique = process.env.CD_NOTES_GRAPHICS === '1';
    const resultat = spawnSync(godot, [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-notes-match.gd')],
      { cwd: racine, encoding: 'utf8', timeout: 420000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_NOTES_OUTPUT: sortie } });
    const journal = (resultat.stdout || '') + (resultat.stderr || '');
    if (resultat.error) throw resultat.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    assert.equal(resultat.status, 0, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('NOTES_MATCH '));
    assert.ok(ligne, 'rapport Godot');
    const rapport = JSON.parse(ligne.slice('NOTES_MATCH '.length));
    assert.deepEqual(rapport.failures, []);
    console.log('Notes de match (Godot) : ' + JSON.stringify(rapport.mesures) + ' · captures : ' + sortie);
  } finally {
    fs.rmSync(profil, { recursive: true, force: true });
    if (!process.env.CD_NOTES_OUTPUT && process.env.CD_NOTES_GRAPHICS !== '1') fs.rmSync(sortie, { recursive: true, force: true });
  }
});
