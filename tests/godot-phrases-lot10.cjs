'use strict';
// Lot 10 des phrases à retirer (21/11/2026) : Recherche, Carrière, Plan de jeu, Match en direct.
// CD_PHRASES_LOT10_CAPTURES=<dossier> : fenêtre réelle 1920 × 1080 et captures ; le profil est jetable.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Lot 10 : écrans sans phrases d’aide, chaque pièce cliquable', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-phrases-lot10-'));
  try {
    const captures = process.env.CD_PHRASES_LOT10_CAPTURES || '';
    const affichage = captures ? ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-phrases-lot10.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 900000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_PHRASES_LOT10_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('PHRASES_LOT10 '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('PHRASES_LOT10 '.length));
    console.log(['Destinations :', ...rapport.destinations, 'Contrôles : ' + rapport.checks].join(String.fromCharCode(10)));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
