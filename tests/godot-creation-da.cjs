'use strict';
// Création de carrière, étape « 1 Club », DA « grille de cartes optimisée » : barre haute, pays et championnats, cartes triables et
// filtrables, panneau du club choisi, or réservé à « Continuer avec … », aucune petite fenêtre, 1280×720 sans défilement (Monde).
// Captures : CD_CREATION_DA_CAPTURES=<dossier> (rendu x11).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Création DA : grille de cartes, panneau du club, aucune petite fenêtre', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-creation-da-'));
  try {
    const captures = process.env.CD_CREATION_DA_CAPTURES || '';
    const affichage = captures ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-creation-da.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_CREATION_DA_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('CREATION_DA '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('CREATION_DA '.length));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
