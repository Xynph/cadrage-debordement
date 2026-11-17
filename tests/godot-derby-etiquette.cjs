'use strict';
// Étiquette « Derby » sur le prochain match (Bureau, Composition, Préparation) : carrière world-champ, club 5 (Bayonne),
// un match joué puis jour du deuxième match, un derby contre un rival semé (DERBYS). Le moteur projette next.derby ;
// Godot pose la pastille dorée « DERBY ». Captures (affichage graphique) : CD_DERBY_GRAPHICS=1 CD_DERBY_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Étiquette Derby sur le prochain match (Bureau, Composition, Préparation)', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-derby-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    try {
      let m = M.creer(jeu, 5);
      m = M.jouer(jeu, m, 1);
      m = M.jusquAuMatch(jeu, m);
      assert.ok(m.next?.derby?.tension >= 60, 'le deuxième match du club 5 est un derby : ' + JSON.stringify(m.next?.derby));
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_DERBY_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-derby-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_DERBY_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-derby-etiquette.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_DERBY_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('DERBY '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('DERBY '.length));
    console.log('Étiquette Derby (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
