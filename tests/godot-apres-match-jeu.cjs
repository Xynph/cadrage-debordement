'use strict';
// Après-match dans le vrai jeu (Godot réel + worker réel, carrière Monde) : tests/godot-apres-match-jeu.gd.
// Consultation d'une fiche de club depuis l'après-match, retour par « Continuer », validation du résultat.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;
test('Après-match dans le jeu : classement complet, consultation et retour, validation', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 900000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-apres-match-'));
  try {
    const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-apres-match-jeu.gd')], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile }, encoding: 'utf8', windowsHide: true, timeout: 840000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(output.trim().split('\n').filter(l => /contrôles|FAIL|ERROR/.test(l)).join('\n'));
    if (result.error) throw result.error;
    assert.equal(result.status, 0, output.slice(-6000));
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
    assert.match(output, /Après-match jeu Godot · \d+ contrôles réussis/);
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
