'use strict';
// Réception · message « Analyse vidéo » (revue FM27, idée 28) : panneau de l’analyste, verdicts → petite fenêtre,
// onglets sur place, ballons des essais → fiche ; 2560×1440 et 1920×1080. Carrière Monde réelle ; ignorée sans SDK.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Réception : message « Analyse vidéo » du dernier match', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-analyste-video-'));
  try {
    const captures = process.env.CD_ANALYSTE_CAPTURES || '';
    const affichage = captures ? ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-analyste-video.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 600000, windowsHide: true,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: process.env.CD_GODOT_DATA_DIR || profil, CD_ANALYSTE_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('ANALYSTE_VIDEO '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('ANALYSTE_VIDEO '.length));
    console.log(['Destinations :', ...rapport.destinations, 'Contrôles : ' + rapport.checks].join('\n'));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
