'use strict';
// Direct en tableau de bord (revue FM27, option A de Léo du 22/11/2026) capturé en vrai match (2e mi-temps puis fin de match,
// 2560x1440 et 1920x1080), match à vitesse maximale, causerie prononcée (moral). CD_PLANCHE_DIRECT_2D=<dossier> reçoit
// direct-tableau-*.png. Jeu rendu : à lancer sur le bureau caché (godot-slot.ps1).
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-planche-direct-tableau : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-planche-direct-tableau-'));
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
{
  const dossier = sortie; fs.mkdirSync(dossier, {recursive: true});
  // Profil de jeu neuf à chaque passage (les copies de sécurité d'un passage précédent ne s'accumulent pas).
  if (process.env.CD_PLANCHE_PROFIL) fs.rmSync(path.join(process.env.CD_PLANCHE_PROFIL, 'jeu'), {recursive: true, force: true});
  fs.copyFileSync(path.join(directory, 'monde.json'), path.join(dossier, 'monde.json'));
  const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(process.env.CD_PLANCHE_PROFIL || directory, 'jeu', 'PrototypeGodot'),
    CD_PLANCHE_DIRECT_2D: dossier, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '8', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
  for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
  const result = spawnSync(godot, ['--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-planche-direct-tableau.gd')],
    {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.split(/\r?\n/).filter(l => /PLANCHE_DIRECT_TABLEAU|ECHEC|SCRIPT ERROR|^  - /.test(l)).join('\n'));
  fs.rmSync(path.join(dossier, 'monde.json'), {force: true});
  if (result.status !== 0 || /SCRIPT ERROR/.test(output)) echecs++;
}
fs.rmSync(directory, {recursive: true, force: true});
process.exit(echecs ? 1 : 0);
