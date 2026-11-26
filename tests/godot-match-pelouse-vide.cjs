'use strict';
// Pelouse vide en transition dans le VRAI écran du match (vraie interface, vraie régie, vraie vue 3D, vrai écran
// intermédiaire), alimenté par un VRAI match du moteur : toute la première mi-temps, minute par minute (temps forts,
// écran intermédiaire, tirs au but et transformations). Film 1305c/film-2 image 0588 et films du 26/11 (sonde de
// tools/match-filme) : pendant le fondu, la caméra montrait la pelouse sans joueur (entrée d'un temps fort après un
// tir au but : le ballon repartait de derrière les poteaux ; sortie vers l'écran intermédiaire après un tir au but).
// Carrière Monde préparée ici (CD_MATCH_PELOUSE_EXPORT=<carriere.json> pour en reprendre une) ; ignoré sans SDK.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-match-pelouse-vide : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-match-pelouse-vide-'));
// Temps fort fini aux poteaux : tir au but (pénalité) ou transformation.
const TIRS = ['goal', 'miss', 'transformation'];
{
  let exportText = process.env.CD_MATCH_PELOUSE_EXPORT ? fs.readFileSync(process.env.CD_MATCH_PELOUSE_EXPORT, 'utf8') : '';
  if (!exportText) {
    // Carrière Monde arrêtée le jour du match (même préparation que godot-match-arrets-ecran.cjs).
    const dataDir = fs.mkdtempSync(path.join(directory, 'carriere-'));
    const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
    let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
    let model = call('new_career', {mode: 'world-champ', club: 0});
    for (let day = 0; day < 120; day++) { model = settleClubMeetings(model, call); if (model.meta.calendarCadence?.matchReady) break; model = call('advance_day', {fromDate: model.meta.calendarToday}); }
    model = settleClubMeetings(model, call); model = call('auto_lineup'); if (!model.selection?.valid) call('promote_cover', {confirmed: true});
    exportText = call('export').meta.exportText;
    bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
  }
  fs.writeFileSync(path.join(directory, 'monde.json'), exportText);
  // Vrai match de cette carrière joué par le moteur (temps forts projetés par match-direct.cjs, comme dans le jeu) :
  // toute la première mi-temps, minute par minute. Ses plans et événements réels sont rejoués par la vraie régie
  // dans le .gd ; les événements (liste qui ne fait que s'allonger) sont gardés une fois, chaque minute en garde le compte.
  const vrai = premiereMiTemps(exportText);
  fs.writeFileSync(path.join(directory, 'vrai-match.json'), JSON.stringify(vrai));
  const tfs = vrai.vies.map(v => v.direct?.tempsFort).filter(Boolean);
  const auxPoteaux = tfs.filter(tf => TIRS.includes(tf.plans.at(-1)?.kind)).length;
  console.log('Vrai match (' + vrai.niveau + ') : ' + vrai.vies.length + ' minutes, ' + tfs.length + ' temps forts dont ' + auxPoteaux + ' finis par un tir au but ou une transformation');
  assert.ok(auxPoteaux >= 1, 'Vrai match : au moins un temps fort fini aux poteaux en première mi-temps');
}
function premiereMiTemps(exportText) {
  const niveau = 'dynamique';
  const dataDir = fs.mkdtempSync(path.join(directory, 'match-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true, matchHighlights: niveau});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('import', {text: exportText});
  const essayer = (command, payload) => { try { return call(command, payload); } catch { return model; } };
  model = call('begin_match');
  const causerie = () => { for (let k = 0; k < 20; k++) { const s = model.clubLife?.matchTalks?.scene; if (!s) return; model = call('match_talk_continue', {key: s.key, phase: s.phase, skip: true}); } };
  const vies = [];
  let events = [];
  for (let t = 0; t < 120 && model.live && !model.live.finished; t++) {
    causerie();
    if (model.live.paused) model = essayer('pause', {paused: false});
    model = essayer('tick', {steps: 1, minute: true, temps_forts: niveau});
    const live = model.live;
    if (!live || live.atBreak || live.finished) break;
    const evts = live.events || [];
    if (evts.length >= events.length) events = evts;
    vies.push({...live, events: undefined, nombreEvents: evts.length});
  }
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
  return {niveau, events, vies};
}
const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(directory, 'jeu', 'PrototypeGodot'),
  CD_MATCH_PELOUSE_ARTIFACTS: directory, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '4', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-pelouse-vide.gd')],
  {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
const output = (result.stdout || '') + (result.stderr || ''); console.log(output);
fs.rmSync(directory, {recursive: true, force: true});
if (result.error) throw result.error;
assert.equal(result.status, 0, output);
assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
assert.match(output, /MATCH_PELOUSE_VIDE \d+ controles, 0 echec/);
