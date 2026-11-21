'use strict';
// Carte joueur au survol dans le direct (fiche complète, choix de Léo du 21/11/2026) : survol d'un joueur de Mon XV,
// Échap, souris qui part, clic (petite fenêtre), captures en jeu 2560x1440 puis 1920x1080. Jeu rendu : à lancer sur le
// bureau caché (godot-slot.ps1). CD_PLANCHE_CARTE_JOUEUR=<dossier> reçoit carte-*.png.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-planche-carte-joueur : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const {createBridge} = require('../native/engine/worker.cjs'), {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-planche-carte-joueur-'));
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
const sortie = process.env.CD_PLANCHE_CARTE_JOUEUR || path.join(directory, 'captures');
let echecs = 0;
for (const variante of ['carte']) {
  const dossier = sortie; fs.mkdirSync(dossier, {recursive: true});
  fs.copyFileSync(path.join(directory, 'monde.json'), path.join(dossier, 'monde.json'));
  const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_DATA_DIR: path.join(process.env.CD_PLANCHE_PROFIL || directory, 'jeu-' + variante, 'PrototypeGodot'),
    CD_PLANCHE_CARTE_JOUEUR: dossier, CD_MATCH_TEMPS_FORTS: '1', CD_MATCH_TEMPS_FORTS_HORLOGE: 'eclair', CD_MATCH_TEMPS_FORTS_VITESSE: '4', CD_MATCH_TEMPS_FORTS_NIVEAU: 'cles', CD_GODOT_SEED: '3'};
  for (const name of ['CD_VARIANTE_VISUELLE', 'CD_MATCH_GESTES', 'CD_MATCH_CHOREGRAPHE', 'CD_MATCH_TEMPS_FORTS_ENTRACTE', 'CD_MATCH_SORTIE']) delete env[name];
  const result = spawnSync(godot, ['--audio-driver', 'Dummy', '--max-fps', '60', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-planche-carte-joueur.gd')],
    {env, stdio: ['ignore', fs.openSync(path.join(dossier, 'journal.log'), 'w'), fs.openSync(path.join(dossier, 'journal-erreurs.log'), 'w')], windowsHide: true, timeout: 900000});
  // Journal écrit au fil de l'eau (lisible pendant la partie), relu à la fin.
  const output = fs.readFileSync(path.join(dossier, 'journal.log'), 'utf8') + fs.readFileSync(path.join(dossier, 'journal-erreurs.log'), 'utf8');
  console.log(output.split(/\r?\n/).filter(l => /PLANCHE_CARTE_JOUEUR|ECHEC|SCRIPT ERROR|ERROR:|^  - /.test(l)).join('\n'));
  fs.rmSync(path.join(dossier, 'monde.json'), {force: true});
  if (result.status !== 0 || /SCRIPT ERROR/.test(output)) echecs++;
}
fs.rmSync(directory, {recursive: true, force: true});
process.exit(echecs ? 1 : 0);
