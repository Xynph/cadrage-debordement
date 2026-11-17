'use strict';
// Réglage « Conférences ordinaires : y aller / envoyer l'adjoint » dans les Paramètres : interface Godot réelle + worker
// réel, carrière Monde world-champ (tests/godot-reglage-conferences.gd). Règle moteur : tests/presse-rapide-monde.cjs.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;

test('Réglage des conférences ordinaires dans les Paramètres', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 900000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-reglage-conf-'));
  try {
    const fenetre = process.env.CD_REGLAGE_CAPTURES ? [] : ['--headless'];
    const result = spawnSync(godot, [...fenetre, '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-reglage-conferences.gd')], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile }, encoding: 'utf8', windowsHide: true, timeout: 840000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(output.trim().split('\n').filter(l => /CD_REGLAGE|contrôles|FAIL|ERROR/.test(l)).join('\n'));
    if (result.error) throw result.error;
    assert.equal(result.status, 0, output.slice(-6000));
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
    assert.match(output, /Réglage conférences Godot · \d+ contrôles réussis/);
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
