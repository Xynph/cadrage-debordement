'use strict';
// Tests physiques avant le match (idée FM27 n° 36, choix A de Léo du 23/11/2026) : sous-page de l'avant-match, onglet
// Blessures de la fiche joueur, message du médecin dans la Réception. Carrière Monde préparée ici avec des titulaires
// revenus de blessure (tools/ecrans-filmes/preparer-carriere.cjs --reprises), importée dans le vrai jeu.
// CD_TP_CAPTURES=<dossier> (+ CD_TP_TAILLE=LxH) : captures final-*.png.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { preparer } = require('../tools/ecrans-filmes/preparer-carriere.cjs');

test('Tests physiques : sous-page, fiche Blessures, message du médecin (carrière Monde)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 900000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-tests-physiques-'));
  try {
    const exportPath = path.join(profile, 'carriere.json');
    preparer({ sortie: exportPath, club: 102, graine: 4242, matchs: 1, reprises: 5 });
    const captures = process.env.CD_TP_CAPTURES;
    const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
      ...(captures ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
      '--script', path.resolve(__dirname, 'godot-tests-physiques.gd'),
    ], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(profile, 'donnees'), CD_TP_EXPORT: exportPath },
      encoding: 'utf8', windowsHide: true, timeout: 420000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(output.trim().split('\n').filter(l => /TESTS_PHYSIQUES|FAIL|SCRIPT ERROR|Parse Error/.test(l)).join('\n'));
    if (result.error) throw result.error;
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/, output.slice(-6000));
    assert.match(output, /TESTS_PHYSIQUES \d+ controles, 0 echec/, output.slice(-6000));
    assert.equal(result.status, 0, output.slice(-6000));
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
