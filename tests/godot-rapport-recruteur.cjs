'use strict';
// Rapport du recruteur (option A, 22/11/2026) : sous-page d'une piste du marché, lettre → barème en petite fenêtre,
// lignes de la liste comparée → fiches, tuiles → offre au joueur, pastille du prêt. Godot réel + worker réel, carrière Monde.
// Captures : CD_RAPPORT_RECRUTEUR_CAPTURES=<dossier> (rendu x11).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Rapport du recruteur : lettre, liste comparée, tuiles, prêt', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-rapport-recruteur-'));
  try {
    const captures = process.env.CD_RAPPORT_RECRUTEUR_CAPTURES || '';
    const affichage = captures ? ['--display-driver', process.platform === 'win32' ? 'windows' : 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', process.env.CD_RAPPORT_RECRUTEUR_RESOLUTION === '2560' ? '2560x1440' : '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-rapport-recruteur.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_RAPPORT_RECRUTEUR_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('RAPPORT_RECRUTEUR '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('RAPPORT_RECRUTEUR '.length));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
