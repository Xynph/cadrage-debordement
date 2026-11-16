'use strict';
// Écran entre deux temps forts : statistiques et lecture de Gabi seulement sur un échantillon
// suffisant (lot 5, 16/11/2026). Fixture de projection, exécution Godot sans affichage ; ignorée
// sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-match-echantillon.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-match-echantillon-'));
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-echantillon.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 180000,
  env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
});
const log = (result.stdout || '') + (result.stderr || '');
console.log(log);
fs.rmSync(root, {recursive: true, force: true});
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /MATCH_ECHANTILLON \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
