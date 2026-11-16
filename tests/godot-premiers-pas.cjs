'use strict';
// Premiers pas guidés par Gabi (carte du Bureau en pré-saison, objectifs cochés par événements réels, jamais
// répétés après la fin) : carrière Monde réelle. Exécution native Godot, ignorée sans SDK.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-premiers-pas.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-premiers-pas-'));
const result = spawnSync(godot, ['--headless', '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-premiers-pas.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 420000,
  env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /PREMIERS_PAS \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
