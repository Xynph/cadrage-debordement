'use strict';
// Planche « écran 2D du direct » (choix visuel ouvert, demande de Léo du 21/11/2026) : variantes A et B
// (CD_VARIANTE_VISUELLE) capturées en jeu en 2560 × 1440 et 1920 × 1080. Jeu rendu : à lancer sur le bureau caché
// (godot-slot.ps1). CD_PLANCHE_DIRECT_2D=<dossier> reçoit <variante>/direct-2d-*.png. Carrière Monde préparée ici.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-planche-direct-2d : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-planche-direct-2d-'));
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
const sortie = process.env.CD_PLANCHE_DIRECT_2D || path.join(directory, 'captures');
let echecs = 0;
for (const variante of (process.env.CD_PLANCHE_VARIANTES || 'A,B').split(',')) {
  const dossier = path.join(sortie, variante); fs.mkdirSync(dossier, {recursive: true});
  fs.copyFileSync(path.join(directory, 'monde.json'), path.join(dossier, 'monde.json'));
  const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(directory, 'jeu-' + variante, 'PrototypeGodot'),
    CD_PLANCHE_DIRECT_2D: dossier, CD_VARIANTE_VISUELLE: variante, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '4', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
  for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
  const result = spawnSync(godot, ['--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-planche-direct-2d.gd')],
    {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.split(/\r?\n/).filter(l => /PLANCHE_DIRECT_2D|ECHEC|SCRIPT ERROR|^  - /.test(l)).join('\n'));
  fs.rmSync(path.join(dossier, 'monde.json'), {force: true});
  if (result.status !== 0 || /SCRIPT ERROR/.test(output)) echecs++;
}
fs.rmSync(directory, {recursive: true, force: true});
process.exit(echecs ? 1 : 0);
