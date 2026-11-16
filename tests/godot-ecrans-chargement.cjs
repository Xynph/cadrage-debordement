'use strict';
// Écrans de chargement (décision de Léo, 16/11/2026) : seuls les vrais chargements (ouverture du jeu, création de
// carrière, coup d'envoi, Continuer, sauvegarde automatique) ont un panneau animé ; décisions et menus restent
// instantanés. Godot réel + worker réel, carrière Monde (world-champ) : tests/godot-ecrans-chargement.gd.
// Moteur seul (tranche « sauvegarde » de Continuer) : tests/sauvegarde-journal-monde.cjs.
// CD_ECRANS_CAPTURE=<préfixe> : rendu fenêtré 1920×1080 et captures PNG (≤ 1280 px).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;
const capture = process.env.CD_ECRANS_CAPTURE;

test('Écrans de chargement : vrais chargements avec panneau, décisions et menus instantanés', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 900000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-ecrans-chargement-'));
  try {
    const display = capture ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const result = spawnSync(godot, [...display, '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-ecrans-chargement.gd')], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile }, encoding: 'utf8', windowsHide: true, timeout: 840000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(output.trim().split('\n').filter(l => /CD_ECRANS|contrôles|FAIL|ERROR/.test(l)).join('\n'));
    if (result.error) throw result.error;
    assert.equal(result.status, 0, output.slice(-6000));
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
    assert.match(output, /Écrans de chargement Godot · \d+ contrôles réussis/);
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
