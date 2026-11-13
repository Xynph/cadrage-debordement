'use strict';
// Gabi dans le bandeau du haut et chez lui au Bureau (option « A + C » de Léo, 13/11/2026) : carrière Monde
// réelle (moteur Node). Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
// Captures (hors CI) : CD_GABI_CAPTURES=<dossier> sous un affichage réel.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-gabi-bandeau.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gabi-bandeau-'));
const result = spawnSync(godot, [...(process.env.CD_GABI_CAPTURES ? [] : ['--headless']), '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-gabi-bandeau.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 420000,
  env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /GABI_BANDEAU \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
