'use strict';
// Club, DA « Deux colonnes, le conseil à gauche » : conseil, confiance et bilans, À décider, vestiaire, nom = fiche / survol = mini-fiche,
// sous-pages du staff et confirmations en place, aucun or, aucune petite fenêtre. Godot réel + worker réel, carrière Monde (world-champ).
// Captures : CD_CLUB_DA_CAPTURES=<dossier> (rendu x11).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Club DA : deux colonnes, conseil, sous-pages du staff, aucune petite fenêtre', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-club-da-'));
  try {
    const captures = process.env.CD_CLUB_DA_CAPTURES || '';
    const affichage = captures ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-club-da.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_CLUB_DA_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('CLUB_DA '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('CLUB_DA '.length));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
