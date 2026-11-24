'use strict';
// Club › Organigramme (option B : un anneau par service) : survol, clic sur chaque membre (petite fenêtre refermée par
// Échap, ✕ et clic à côté), aucun chiffre exact du moteur, « Toi » → Carrière. Godot réel + worker réel, carrière Monde.
// Captures : CD_ORGANIGRAMME_CAPTURES=<dossier> (rendu graphique : x11 sous Linux, fenêtre Windows sinon).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Club Organigramme : survol, chaque membre ouvre et ferme sa petite fenêtre', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-organigramme-'));
  try {
    const captures = process.env.CD_ORGANIGRAMME_CAPTURES || '';
    const rendu = ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'];
    const affichage = !captures ? ['--headless'] : process.platform === 'win32' ? rendu : ['--display-driver', 'x11', ...rendu];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-club-organigramme.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_ORGANIGRAMME_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('CLUB_ORGANIGRAMME '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('CLUB_ORGANIGRAMME '.length));
    console.log(`organigramme : ${rapport.checks} vérifications`);
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
