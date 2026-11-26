'use strict';
// Préchauffage des portraits de l'effectif (ui/portrait_warmup.gd) : carrière Monde réelle, Godot natif.
// Au repos sur le Bureau, tout l'effectif passe en cache ; la 1re Composition ne fabrique plus ses portraits
// d'un bloc ; rien n'est fabriqué pendant une commande moteur en attente. Ignorée sans SDK.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-portraits-prechauffage.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }
// Chronos (1re Composition < 250 ms, étape < 50 ms) : seuils inchangés, mais mesurés sur le MEILLEUR de 3 passes.
// La charge d'un runner ne fait qu'ajouter du temps ; une vraie régression (335 ms sans préchauffage) échoue aux 3 passes.
// Un échec fonctionnel (code 1, crash) n'est jamais relancé : seul le code 2 (chronos seuls hors budget) l'est.
const PASSES = 3;
let log = '';
let status = 1;
for (let passe = 1; passe <= PASSES; passe++) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-prechauffage-'));
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-portraits-prechauffage.gd')], {
    windowsHide: true, encoding: 'utf8', timeout: 300000,
    env: {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot')},
  });
  log = (result.stdout || '') + (result.stderr || '');
  console.log(log);
  fs.rmSync(root, {recursive: true, force: true});
  if (result.error) throw result.error;
  status = result.status;
  if (status !== 2) break;
  console.log(`Passe ${passe}/${PASSES} : chrono hors budget seulement` + (passe < PASSES ? ", nouvelle passe." : "."));
}
assert.equal(status, 0, log);
assert.match(log, /PRECHAUFFAGE PORTRAITS : \d+ contrôles ; 0 échec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
