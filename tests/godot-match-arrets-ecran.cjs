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
  const exportText = call('export').meta.exportText;
  fs.writeFileSync(path.join(directory, 'monde.json'), exportText);
  bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
  // Vrai match de cette carrière joué par le moteur (temps forts projetés par match-direct.cjs, comme dans le jeu) :
  // le premier temps fort qui finit sur un en-avant, puis les minutes suivantes (écran intermédiaire ou liaison).
  // Ses plans et événements réels sont rejoués par la vraie régie dans le .gd (vérificateur de #1319 : le test
  // d'avant fabriquait des plans avec scene.team, absent des vrais plans).
  const vrai = vraiMatchAvecEnAvant(exportText);
  assert.ok(vrai, 'Vrai match : aucun temps fort finissant sur un en-avant');
  fs.writeFileSync(path.join(directory, 'vrai-match.json'), JSON.stringify(vrai));
  console.log('Vrai match (' + vrai.niveau + ') : temps fort ' + vrai.vies[0].direct.tempsFort.horlogeDebut + ' avec ' +
    vrai.vies[0].direct.tempsFort.plans.map(p => p.kind).join(', ') + ', puis ' + (vrai.vies.length - 1) + ' minute(s)');
}
function vraiMatchAvecEnAvant(exportText) {
  for (const niveau of ['etendus', 'integral']) {
    const dataDir = fs.mkdtempSync(path.join(directory, 'match-'));
    const bridge = createBridge({dataDir, seed: 7, now: 1700000000000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true, matchHighlights: niveau});
    let id = 0; const call = (command, payload = {}) => { const r = bridge.handle({id: ++id, command, payload}); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
    const essayer = (command, payload) => { try { return call(command, payload); } catch { return model; } };
    let model = call('import', {text: exportText});
    model = call('begin_match');
    const causerie = () => { for (let k = 0; k < 20; k++) { const s = model.clubLife?.matchTalks?.scene; if (!s) return; model = call('match_talk_continue', {key: s.key, phase: s.phase, skip: true}); } };
    let vies = null;
    for (let t = 0; t < 220 && model.live && !model.live.finished; t++) {
      causerie();
      if (model.live.paused || model.live.atBreak) model = essayer('pause', {paused: false});
      model = essayer('tick', {steps: 1, minute: true, temps_forts: niveau});
      const tf = model.live?.direct?.tempsFort;
      if (vies) {
        vies.push(model.live);
        // Jusqu'au temps fort suivant (liaison possible) ou trois minutes d'écran intermédiaire.
        if ((tf && tf.cle !== vies[0].direct.tempsFort.cle) || vies.length >= 4) break;
      } else if (tf && tf.plans.length && tf.plans.at(-1).kind === 'hand-fault') vies = [model.live];
    }
    bridge.close?.(); fs.rmSync(dataDir, {recursive: true, force: true});
    if (vies) return {niveau, vies};
  }
  return null;
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
