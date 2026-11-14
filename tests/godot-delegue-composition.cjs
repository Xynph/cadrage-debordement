'use strict';
// Délégation de la composition et alerte de fatigue de Gabi, dans le vrai jeu (Godot + moteur Node, carrière
// Monde). Le moteur joue d'abord des matchs délégués avec une feuille jamais refaite (case décochée) jusqu'à
// l'alerte « titulaires sous 70 % de condition » ; la carrière est exportée, puis le vrai jeu l'importe.
// Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
// Captures (hors CI) : CD_DELEGUE_CAPTURES=<dossier> sous un affichage réel.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const Monde = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-delegue-composition.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-delegue-'));
// Mise au point locale : CD_DELEGUE_SAUVEGARDE_FIXE=<fichier> garde la carrière exportée d'une exécution à l'autre.
const fixe = process.env.CD_DELEGUE_SAUVEGARDE_FIXE;
const sauvegarde = fixe || path.join(root, 'fatigue.json');
if (!(fixe && fs.existsSync(fixe))) {
  const jeu = Monde.ouvrir({ hebdomadaire: true });
  try {
  let model = Monde.creer(jeu);
  for (let w = 0; w < 30 && !model.selection.fatigue; w++) {
    model = jeu.regler(model);
    if (!model.next) { model = jeu.call('finish_round'); continue; }
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    if (model.selection.fatigue) break;
    // Feuille jamais refaite par le staff (délégation de fin de match seule : aucun choix mémorisé, la case reste cochée par défaut).
    model = jeu.call('begin_match');
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    model = jeu.call('finish_round');
    model = jeu.regler(model);
  }
  assert.ok(model.selection.fatigue, 'alerte de fatigue atteinte');
  assert.ok(model.next && !model.live, 'jour de match, rien en cours');
  fs.writeFileSync(sauvegarde, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

const result = spawnSync(godot, [...(process.env.CD_DELEGUE_CAPTURES ? ['--rendering-driver', 'vulkan'] : ['--headless']), '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-delegue-composition.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 540000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot'), CD_DELEGUE_SAUVEGARDE: sauvegarde },
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (!fixe) fs.rmSync(sauvegarde, { force: true });
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /DELEGUE_COMPOSITION \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
