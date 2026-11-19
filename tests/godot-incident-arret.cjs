'use strict';
// Arrêt-incident (blessure, saignement, choc à la tête, première ligne) et choix du manager dans l'écran
// intermédiaire du match (Godot réel, sans moteur) : tests/godot-incident-arret.gd.
// Règles et commande côté moteur : tests/incidents-match.cjs.
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
test('Arrêt-incident : titre selon le motif, choix du remplaçant envoyé au moteur', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 180000 }, () => {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-incident-arret.gd')], {
    env: { ...process.env, CD_GODOT_SELF_TEST: '0' }, encoding: 'utf8', windowsHide: true, timeout: 150000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-4000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
  assert.match(output, /INCIDENT_ARRET_CHECKS \d+ failures=0/);
});
