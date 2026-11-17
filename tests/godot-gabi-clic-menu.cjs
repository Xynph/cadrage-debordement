'use strict';
// Menu principal, bulle de Gabi ouverte (voile) : un seul clic sur « Nouvelle carrière » ouvre la création
// (recette native du 16/11/2026). Exécution native Godot, sautée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-gabi-clic-menu.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gabi-clic-menu-'));
try {
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-gabi-clic-menu.gd')], {
    windowsHide: true, encoding: 'utf8', timeout: 240000,
    env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
  });
  const log = (result.stdout || '') + (result.stderr || '');
  console.log(log);
  if (result.error) throw result.error;
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
  assert.match(log, /GABI CLIC MENU : \d+ contrôles ; 0 échec\(s\)/);
  assert.equal(result.status, 0, log);
} finally { fs.rmSync(root, {recursive: true, force: true}); }
