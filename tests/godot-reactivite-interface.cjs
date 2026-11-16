'use strict';
// Réactivité de l'interface (lot 23) : Godot réel + worker réel, carrière Monde neuve (world-champ).
// Décision optimiste, coût hors moteur d'une décision (< 150 ms, médiane), file de deux clics, refus annulé,
// patch appliqué par sections identique au modèle complet, fiche club en cache et suivi sans relecture ;
// rafraîchissement par écran (ui/screen_refresh.gd) : écran gardé = rendu complet sur 10 écrans, rendu mesuré avant/après.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Réactivité : décision affichée dès le clic, < 150 ms hors moteur, refus annulé, fiche club sans aller-retour, écran gardé si rien de lu n’a changé', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-reactivite-'));
  try {
    const r = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-reactivite-interface.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_GODOT_TIMING: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('REACTIVITE '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('REACTIVITE '.length));
    console.log('REACTIVITE mesures', JSON.stringify(rapport.mesures));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
