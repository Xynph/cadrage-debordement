'use strict';
// Consignes en petite fenêtre pendant le match (idée FM27 n° 33) : carrière Monde préparée côté Node jusqu'au jour du
// match, puis le vrai direct à vitesse maximale jusqu'en 2e mi-temps ; fenêtre ouverte sans pause, crans demandés au
// prochain arrêt de jeu, plan de jeu compris, avis du staff en tendance, captures 2560x1440 puis 1920x1080.
// CD_CAPTURES_CONSIGNES=<dossier> reçoit final-*.png. Jeu rendu : à lancer sur le bureau caché (godot-slot.ps1).
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-consignes-match : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-consignes-match-'));
{
  // Carrière Monde arrêtée le jour du match (même préparation que godot-match-grands-moments.cjs).
  const dataDir = fs.mkdtempSync(path.join(directory, 'carriere-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('new_career', {mode: 'world-champ', club: 0});
  for (let day = 0; day < 120; day++) { model = settleClubMeetings(model, call); if (model.meta.calendarCadence?.matchReady) break; model = call('advance_day', {fromDate: model.meta.calendarToday}); }
  model = settleClubMeetings(model, call); model = call('auto_lineup'); if (!model.selection?.valid) call('promote_cover', {confirmed: true});
  fs.writeFileSync(path.join(directory, 'monde.json'), call('export').meta.exportText);
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
}
const dossier = process.env.CD_CAPTURES_CONSIGNES || path.join(directory, 'captures');
fs.mkdirSync(dossier, {recursive: true});
fs.copyFileSync(path.join(directory, 'monde.json'), path.join(dossier, 'monde.json'));
const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(directory, 'jeu', 'PrototypeGodot'),
  CD_CAPTURES_CONSIGNES: dossier, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '8', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE', 'CD_VARIANTE_VISUELLE']) delete env[name];
const result = spawnSync(godot, ['--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-consignes-match.gd')],
  {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
const output = (result.stdout || '') + (result.stderr || '');
console.log(output.split(/\r?\n/).filter(l => /CONSIGNES_MATCH|ECHEC|SCRIPT ERROR|^  - /.test(l)).join('\n'));
fs.rmSync(path.join(dossier, 'monde.json'), {force: true});
fs.rmSync(directory, {recursive: true, force: true});
process.exit(result.status !== 0 || /SCRIPT ERROR/.test(output) ? 1 : 0);
