'use strict';
// Case « Confier aussi les prolongations au staff » (onglet Contrats) sur un modèle factice : aucun moteur Node.
// Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
// Capture (hors CI) : CD_PROLONGATIONS_CAPTURES=<dossier> sous un affichage réel (prolongations-staff.png).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-prolongations-staff.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-prolongations-'));
const captures = process.env.CD_PROLONGATIONS_CAPTURES;
if (captures) fs.mkdirSync(captures, { recursive: true });
const result = spawnSync(godot, [...(captures ? ['--rendering-driver', 'vulkan'] : ['--headless']), '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-prolongations-staff.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 240000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot') },
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /PROLONGATIONS_STAFF \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
if (captures) assert.ok(fs.existsSync(path.join(captures, 'prolongations-staff.png')), 'capture prolongations-staff.png écrite');
