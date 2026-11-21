'use strict';
// Carrière Monde, club 102 : « Activer les candidatures » réussit dans le vrai Godot (borne de clubs de la sauvegarde).
// CD_CANDIDATURES_CAPTURES=<dossier> : fenêtre réelle 1920 × 1080 et capture ; le profil est jetable.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Monde, club 102 : activer les candidatures depuis Mobilité et recrutement', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = process.env.CD_GODOT_DATA_DIR_TEST || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-candidatures-'));
  try {
    const captures = process.env.CD_CANDIDATURES_CAPTURES || '';
    const affichage = captures ? ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-candidatures-monde.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 600000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: profil, CD_CANDIDATURES_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('CANDIDATURES_MONDE '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('CANDIDATURES_MONDE '.length));
    console.log('Contrôles : ' + rapport.checks);
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { if (!process.env.CD_GODOT_DATA_DIR_TEST) fs.rmSync(profil, { recursive: true, force: true }); }
});
