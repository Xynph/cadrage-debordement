'use strict';
// « Continuer » jusqu'au prochain événement : interface Godot réelle + worker réel, carrière Monde au 13/07/2026.
//   1. tests/godot-career-progression.gd : choix du bouton principal (« Continuer »), « Jour suivant » d'un seul
//      jour, jamais le jour d'un match, réglages d'arrêt transmis au moteur.
//   2. tests/godot-continuer.gd : clic sur « Continuer », panneau de progression, arrêt motivé, « + 1 j » et
//      Ctrl+J, « Arrêter » au milieu d'une avance.
// Moteur seul (règle d'arrêt, équivalence avec N « Jour suivant ») : tests/continuer-evenement-monde.cjs.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE;
const lancer = (script, env = {}, timeout = 120000) => {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, script)], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', ...env }, encoding: 'utf8', windowsHide: true, timeout,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.trim().split('\n').filter(l => /CD_CONTINUER|contrôles|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
  return output;
};

test('Bouton principal « Continuer » et « Jour suivant » (règles d’interface)', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const output = lancer('godot-career-progression.gd');
  assert.match(output, /Parcours quotidien Godot · \d+ contrôles réussis/);
});

test('« Continuer » dans le jeu : panneau, arrêt motivé, « Arrêter », « Jour suivant » encore là', { skip: !godot && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent', timeout: 600000 }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-continuer-'));
  try {
    const output = lancer('godot-continuer.gd', { CD_GODOT_DATA_DIR: profile }, 480000);
    assert.match(output, /Continuer Godot · \d+ contrôles réussis/);
  } finally { fs.rmSync(profile, { recursive: true, force: true }); }
});
