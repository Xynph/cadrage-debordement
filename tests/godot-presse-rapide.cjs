'use strict';
// Conférence de presse rapide : interface Godot réelle + worker réel, carrière Monde au 13/07/2026
// (tests/godot-presse-rapide.gd). Grand moment en un clic par question, conférence ordinaire confiée à Gabi en deux
// clics, réglage « Conférences ordinaires : envoyer l'adjoint ». Moteur seul : tests/presse-rapide-monde.cjs.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;

test('Conférence de presse rapide dans le jeu', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 900000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-presse-rapide-'));
  try {
    const fenetre = process.env.CD_PRESSE_CAPTURES ? [] : ['--headless'];
    const result = spawnSync(godot, [...fenetre, '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-presse-rapide.gd')], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile }, encoding: 'utf8', windowsHide: true, timeout: 840000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(output.trim().split('\n').filter(l => /CD_PRESSE|contrôles|FAIL|ERROR/.test(l)).join('\n'));
    if (result.error) throw result.error;
    assert.equal(result.status, 0, output.slice(-6000));
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
    assert.match(output, /Presse rapide Godot · \d+ contrôles réussis/);
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
