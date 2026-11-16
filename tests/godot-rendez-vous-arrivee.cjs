'use strict';
// Début de carrière Monde, conférence de presse d'arrivée en attente (recette native du 16/11/2026) : refus nommé,
// pas de faux « Stockage à vérifier », invitations menant à la conférence, « Conf. de presse » qui ouvre la salle,
// libellé du bouton principal jamais rogné. Exécution native Godot, sautée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-rendez-vous-arrivee.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-rendez-vous-arrivee-'));
try {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-rendez-vous-arrivee.gd')], {
    windowsHide: true, encoding: 'utf8', timeout: 240000,
    env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
  });
  const log = (result.stdout || '') + (result.stderr || '');
  console.log(log);
  if (result.error) throw result.error;
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
  assert.match(log, /RENDEZ-VOUS ARRIVEE : \d+ contrôles ; 0 échec\(s\)/);
  assert.equal(result.status, 0, log);
} finally { fs.rmSync(root, {recursive: true, force: true}); }
