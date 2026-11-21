'use strict';
// Carte joueur au survol sur les écrans joueurs (Effectif, Composition, Recrutement, Entraînement, Vestiaire) et étoiles
// de capacité au poste en Tactique et Préparation (choix de Léo du 21/11/2026). Jeu rendu : à lancer sur le bureau caché
// (godot-slot.ps1). CD_ETOILES_FICHE_CAPTURES=<dossier> reçoit les captures 2560 et 1920.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-etoiles-fiche-partout : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-etoiles-fiche-'));
const sortie = process.env.CD_ETOILES_FICHE_CAPTURES || path.join(directory, 'captures');
fs.mkdirSync(sortie, {recursive: true});
{
  // Carrière Monde arrêtée la veille du match : dossier adverse (joueurs à surveiller) publié.
  const dataDir = fs.mkdtempSync(path.join(directory, 'carriere-'));
  const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
  let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  let model = call('new_career', {mode: 'world-champ', club: 0});
  for (let day = 0; day < 120; day++) { model = settleClubMeetings(model, call); if (model.meta.calendarCadence?.matchReady) break; model = call('advance_day', {fromDate: model.meta.calendarToday}); }
  model = settleClubMeetings(model, call); model = call('auto_lineup'); if (!model.selection?.valid) call('promote_cover', {confirmed: true});
  fs.writeFileSync(path.join(sortie, 'monde.json'), call('export').meta.exportText);
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
}
const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath,
  CD_GODOT_DATA_DIR: path.join(process.env.CD_ETOILES_FICHE_PROFIL || directory, 'jeu', 'PrototypeGodot'), CD_ETOILES_FICHE_CAPTURES: sortie, CD_GODOT_SEED: '3'};
delete env.CD_VARIANTE_VISUELLE;
const journal = path.join(sortie, 'journal.log'), erreurs = path.join(sortie, 'journal-erreurs.log');
const result = spawnSync(godot, ['--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-etoiles-fiche-partout.gd')],
  {env, stdio: ['ignore', fs.openSync(journal, 'w'), fs.openSync(erreurs, 'w')], windowsHide: true, timeout: 900000});
const output = fs.readFileSync(journal, 'utf8') + fs.readFileSync(erreurs, 'utf8');
console.log(output.split(/\r?\n/).filter(l => /ETOILES_FICHE|ECHEC|SCRIPT ERROR|ERROR:|^  - /.test(l)).join('\n'));
fs.rmSync(path.join(sortie, 'monde.json'), {force: true});
fs.rmSync(directory, {recursive: true, force: true});
process.exit(result.status !== 0 || /SCRIPT ERROR/.test(output) ? 1 : 0);
