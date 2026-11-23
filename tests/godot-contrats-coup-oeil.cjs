'use strict';
// Effectif › Contrats « en un coup d'œil » (revue FM27, idée 12, option A) sur un modèle factice : aucun moteur Node.
// Compteurs d'échéance, lignes (rôle promis, conseil du staff, part de la masse, Prolonger), tris et filtres.
// Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-contrats-coup-oeil.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-contrats-coup-oeil-'));
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-contrats-coup-oeil.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 240000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot') },
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /CONTRATS_COUP_OEIL \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
