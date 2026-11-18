'use strict';
// Première heure de jeu : défis de départ à la création, Gabi guide les deux premières semaines puis
// s'efface, « je connais déjà » : carrière Monde réelle. Exécution native Godot, ignorée sans SDK.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-premiere-heure.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-premiere-heure-'));
const result = spawnSync(godot, ['--headless', '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-premiere-heure.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 420000,
  env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /PREMIERE_HEURE \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
