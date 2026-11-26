'use strict';
// Fil et ligne d'état de l'écran intermédiaire au retour d'un temps fort, dans le VRAI écran du match (vraie
// interface, vraie régie, vrai terrain 2D), alimentés par un VRAI match du moteur : chaque temps fort joué par le
// moteur (plans, événements, borne, fil, déroulé réels) puis la minute qui suit, rejoués par la régie (receive).
// Match filmé du 26/11 (anomalie V4 « journal bloqué à 29′ à la 36′ ») : après un essai montré en 3D, le fil
// restait sur un fait de plusieurs minutes plus tôt (1′ à la 4′, 14′ à la 18′, 41′ à la 44′…) jusqu'au fait suivant.
// Carrière Monde préparée ici ; ignoré sans SDK.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-match-fil-apres-temps-fort : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-match-fil-tf-'));
const TEMPS_FORTS = Number(process.env.CD_FIL_TEMPS_FORTS || 4);
{
  // Carrière Monde arrêtée le jour du match (même préparation que godot-match-arrets-ecran.cjs).
  const dataDir = fs.mkdtempSync(path.join(directory, 'carriere-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('new_career', {mode: 'world-champ', club: 0});
  for (let day = 0; day < 120; day++) { model = settleClubMeetings(model, call); if (model.meta.calendarCadence?.matchReady) break; model = call('advance_day', {fromDate: model.meta.calendarToday}); }
  model = settleClubMeetings(model, call); model = call('auto_lineup'); if (!model.selection?.valid) call('promote_cover', {confirmed: true});
  const exportText = call('export').meta.exportText;
  fs.writeFileSync(path.join(directory, 'monde.json'), exportText);
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
  const sequences = vraisTempsForts(exportText);
  assert.ok(sequences.length >= 2, 'Vrai match : au moins deux temps forts suivis d\'une minute (' + sequences.length + ')');
  fs.writeFileSync(path.join(directory, 'vrai-match.json'), JSON.stringify({sequences}));
  console.log('Vrai match : ' + sequences.map(s => s[0].direct.tempsFort.horlogeDebut + ' (' + s[0].direct.tempsFort.plans.map(p => p.kind).join(', ') + ')').join(' · '));
}
// Vrai match de cette carrière joué par le moteur (temps forts projetés par match-direct.cjs, comme dans le jeu) : chaque
// temps fort (le direct de sa minute) suivi du direct de la minute d'après, quand il n'en ouvre pas un autre.
function vraisTempsForts(exportText) {
  const niveau = 'cles';
  const dataDir = fs.mkdtempSync(path.join(directory, 'match-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true, matchHighlights: niveau});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('import', {text: exportText});
  const essayer = (command, payload) => { try { return call(command, payload); } catch { return model; } };
  model = call('begin_match');
  const causerie = () => { for (let k = 0; k < 20; k++) { const s = model.clubLife?.matchTalks?.scene; if (!s) return; model = call('match_talk_continue', {key: s.key, phase: s.phase, skip: true}); } };
  const sequences = [];
  let attente = null, cle = '';
  for (let t = 0; t < 220 && model.live && !model.live.finished && sequences.length < TEMPS_FORTS; t++) {
    causerie();
    if (model.live.paused || model.live.atBreak) model = essayer('pause', {paused: false});
    model = essayer('tick', {steps: 1, minute: true, temps_forts: niveau});
    const live = model.live, tf = live?.direct?.tempsFort;
    const nouveau = tf && tf.plans?.length && tf.cle !== cle;
    if (attente && !nouveau && !live.atBreak && !live.finished) sequences.push([attente, live]);
    attente = null;
    if (nouveau) { cle = tf.cle; if (live.minute > 2 && !live.atBreak) attente = live; }
  }
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
  return sequences;
}
const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(directory, 'jeu', 'PrototypeGodot'),
  CD_MATCH_FIL_ARTIFACTS: directory, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '4', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-fil-apres-temps-fort.gd')],
  {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
const output = (result.stdout || '') + (result.stderr || ''); console.log(output);
fs.rmSync(directory, {recursive: true, force: true});
if (result.error) throw result.error;
assert.equal(result.status, 0, output);
assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
assert.match(output, /MATCH_FIL_TEMPS_FORT \d+ controles, 0 echec/);
