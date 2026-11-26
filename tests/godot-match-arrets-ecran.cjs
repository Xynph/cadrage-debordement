'use strict';
// Arrêts de jeu rares dans le VRAI écran du match (vraie interface, vraie régie, vraie liaison, vrai écran
// intermédiaire), alimentés par une suite scriptée de faits du moteur : en-avant de A, en-avant de B, mêlée ;
// puis carton suivi d'une blessure. Ces enchaînements n'arrivent presque jamais dans un match filmé
// (vérificateur de #1319). Carrière Monde préparée ici ; ignoré sans SDK.
// CD_MATCH_ARRETS_CAPTURES=<dossier> : jeu rendu (pas --headless ; à lancer sur le bureau caché de godot-slot.ps1),
// une capture PNG par étape copiée dans ce dossier.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-match-arrets-ecran : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-match-arrets-ecran-'));
{
  // Carrière Monde arrêtée le jour du match (même préparation que godot-match-direct-da.cjs).
  const dataDir = fs.mkdtempSync(path.join(directory, 'carriere-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('new_career', {mode: 'world-champ', club: 0});
  for (let day = 0; day < 120; day++) { model = settleClubMeetings(model, call); if (model.meta.calendarCadence?.matchReady) break; model = call('advance_day', {fromDate: model.meta.calendarToday}); }
  model = settleClubMeetings(model, call); model = call('auto_lineup'); if (!model.selection?.valid) call('promote_cover', {confirmed: true});
  fs.writeFileSync(path.join(directory, 'monde.json'), call('export').meta.exportText);
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
}
const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(directory, 'jeu', 'PrototypeGodot'),
  CD_MATCH_ARRETS_ARTIFACTS: directory, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '4', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
for (const name of ['CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
const captures = process.env.CD_MATCH_ARRETS_CAPTURES || '';
const result = spawnSync(godot, [...(captures ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-arrets-ecran.gd')],
  {env, encoding: 'utf8', windowsHide: true, timeout: 900000});
const output = (result.stdout || '') + (result.stderr || ''); console.log(output);
if (captures) {
  fs.mkdirSync(captures, {recursive: true});
  for (const name of fs.readdirSync(directory).filter(n => n.endsWith('.png'))) fs.copyFileSync(path.join(directory, name), path.join(captures, name));
}
fs.rmSync(directory, {recursive: true, force: true});
if (result.error) throw result.error;
assert.equal(result.status, 0, output);
assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
assert.match(output, /MATCH_ARRETS_ECRAN \d+ controles, 0 echec/);
