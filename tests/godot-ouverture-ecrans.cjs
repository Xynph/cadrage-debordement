'use strict';
// Temps d'ouverture des écrans lourds (Effectif, Staff, Club, Finances, Recrutement) : carrière Monde réelle,
// Godot natif. Ignorée sans SDK. Le tableau est imprimé dans le journal.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-ouverture-ecrans.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-ouverture-'));
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-ouverture-ecrans.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 420000,
  env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
});
const log = (result.stdout || '') + (result.stderr || '');
console.log(log);
fs.rmSync(root, {recursive: true, force: true});
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /OUVERTURE ECRANS : \d+ contrôles ; 0 échec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
