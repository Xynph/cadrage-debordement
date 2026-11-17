'use strict';
// Préparation du match, dossier adverse : forme de l'adversaire en pastilles V/N/D (cinq dernières rencontres,
// mêmes rencontres et même ordre que « Les faits récents »). Carrière world-champ, deux matchs joués (délégués)
// pour que l'adversaire suivant ait des résultats. Captures (affichage graphique) : CD_FORME_GRAPHICS=1 CD_FORME_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Préparation : forme de l’adversaire en pastilles V/N/D', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-forme-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    let attendu = [];
    try {
      let m = M.creer(jeu, 102);
      m = M.jouer(jeu, m, 2);
      m = M.jusquAuMatch(jeu, m);
      const recent = m.decisions?.preparation?.recent || null;
      if (Array.isArray(recent)) attendu = recent.slice(0, 5).filter(r => Array.isArray(r.score) && r.score.length === 2).map(r => { const a = r.score[r.side || 0], b = r.score[1 - (r.side || 0)]; return a > b ? 'V' : a < b ? 'D' : 'N'; });
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_FORME_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-forme-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_FORME_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-forme-adverse.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_FORME_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('FORME '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('FORME '.length));
    console.log('Forme adverse (Godot) : ' + JSON.stringify(rapport) + ' ; attendu (moteur) : ' + attendu.join(''));
    assert.deepEqual(rapport.failures, []);
    if (attendu.length) assert.deepEqual(rapport.pastilles, attendu);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
