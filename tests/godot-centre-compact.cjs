'use strict';
// Centre de formation en affichage compact (1024 × 576, 960 × 540, 1200 × 700 ; carrière world-champ, club 5) : parcours
// activés, les six onglets en conteneurs (même structure que la grande page), textes ≥ 11 px, commandes ≥ 24 px, rien
// au-delà du bord droit, filtre, tri, liens et petites fenêtres. Suite GDScript : tests/godot-centre-compact.gd.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Centre en affichage compact (sous 1280 × 720) : six onglets, commandes et petites fenêtres', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-centre-compact-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    try { M.creer(jeu, 5); jeu.call('save'); } finally { jeu.fermer(); }
    const sortie = process.env.CD_CENTRE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-centre-compact-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_CENTRE_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-centre-compact.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 2560x1440x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_CENTRE_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('CENTRE_COMPACT '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('CENTRE_COMPACT '.length));
    console.log('Centre (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    for (const t of ['1024x576', '960x540', '1200x700']) assert.ok(rapport.mesures[t], 'mesure en ' + t);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
