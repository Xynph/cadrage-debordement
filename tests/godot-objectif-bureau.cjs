'use strict';
// Bureau, carte du classement : objectif du conseil avec place actuelle et tendance (« Top 6 · 4e · en avance »).
// Carrière world-champ (Pau, objectif « Top 6 »), deux matchs joués (délégués) pour ouvrir le classement.
// Captures (affichage graphique) : CD_OBJECTIF_GRAPHICS=1 CD_OBJECTIF_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Bureau : objectif du conseil, place actuelle et tendance', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-objectif-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    let rang = null;
    try {
      let m = M.creer(jeu, 4);
      assert.equal(m.club.goal, 'Top 6');
      m = M.jouer(jeu, m, 2);
      rang = m.club.rank;
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_OBJECTIF_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-objectif-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_OBJECTIF_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-objectif-bureau.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_OBJECTIF_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('OBJECTIF '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('OBJECTIF '.length));
    console.log('Objectif (Godot) : ' + JSON.stringify(rapport) + ' ; rang moteur : ' + rang);
    assert.deepEqual(rapport.failures, []);
    const tendance = rang <= 4 ? 'en avance' : rang <= 6 ? 'dans l’objectif' : rang <= 8 ? 'à portée' : 'en retard';
    assert.ok(rapport.texte.startsWith('Top 6 · ' + rang + (rang === 1 ? 'er' : 'e') + ' · ' + tendance), rapport.texte);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
