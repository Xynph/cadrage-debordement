'use strict';
// Avant-match · « Dernière rencontre » (option B, 21/11/2026) : pastille du bandeau (absente en début de saison),
// petite fenêtre du bilan en 2560×1440, 1920×1080 et 1280×720, fermetures Échap / ✕ / clic à côté,
// « tes choix » → Plan de jeu, club adverse → sa fiche. Carrière Monde réelle ; ignorée sans SDK.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Avant-match : pastille et petite fenêtre de la dernière rencontre', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-avant-match-bilan-'));
  try {
    const captures = process.env.CD_BILAN_CAPTURES || '';
    const affichage = captures ? ['--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-avant-match-bilan.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 600000, windowsHide: true,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: process.env.CD_GODOT_DATA_DIR || profil, CD_BILAN_CAPTURES: captures ? path.resolve(captures) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('AVANT_MATCH_BILAN '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('AVANT_MATCH_BILAN '.length));
    console.log(['Destinations :', ...rapport.destinations, 'Contrôles : ' + rapport.checks].join('\n'));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
