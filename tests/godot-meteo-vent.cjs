'use strict';
// Météo et vent montrés au manager : carrière world-champ (club 102) amenée au jour de match, puis le vrai Godot
// lance le coup d'envoi : vestiaire d'avant-match (météo, camp favorisé en 1re période, conseil du staff), bandeau
// du direct et changement de camp à la mi-temps. Captures (affichage graphique) : CD_METEO_GRAPHICS=1 CD_METEO_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Météo et vent : avant-match, bandeau du direct, mi-temps', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-meteo-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    try {
      let m = M.jusquAuMatch(jeu, M.creer(jeu, 102));
      if (!m.selection.valid) m = jeu.call('auto_lineup');
      if (!m.selection.valid) m = jeu.call('promote_cover', { confirmed: true });
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_METEO_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-meteo-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_METEO_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-meteo-vent.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 420000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_METEO_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('METEO '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-3000));
    const rapport = JSON.parse(ligne.slice('METEO '.length));
    console.log('Météo (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
