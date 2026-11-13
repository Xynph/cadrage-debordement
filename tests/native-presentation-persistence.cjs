'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {skipMatchTalk}=require('./helpers/scene-match-talks.cjs');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {test} = require('node:test');
const {isDeepStrictEqual} = require('node:util');
const {createBridge} = require('../native/engine/worker.cjs');
const {refuseSavePublication} = require('./helpers/save-publication-refusal.cjs');

test('Les images seules ne réécrivent ni la carrière ni son secours', () => {
 const parent = fs.realpathSync(os.tmpdir());
 const dataDir = fs.mkdtempSync(path.join(parent, 'cd-native-presentation-'));
 const current = path.join(dataDir, 'PrototypeGodot', 'donnees.json');
 const backup = path.join(path.dirname(current), 'donnees-precedentes.json');
 const realNow = Date.now;
 let now = 1794315600000;
 let bridge;
 let id = 0;
 const request = (command, payload = {}) => {
  now += 1000;
  return bridge.handle({id: ++id, command, payload});
 };
 const good = (command, payload) => {
  const result = request(command, payload);
  assert.equal(result.ok, true, result.error);
  return result.model;
 };
 try {
  Date.now = () => now;
  // Carrière Monde, réglée comme le vrai jeu (calendrier journalier, presse obligatoire) ; le direct
  // s'ouvre le jour de la première rencontre du club.
  bridge = createBridge({dataDir, seed: 411, dailyCalendar: true, mandatoryPress: true, internationalCareer: true});
  let career = settleClubMeetings(good('new_career', {mode: 'world-champ', club: 0}), good);
  for (let day = 0; !(career.meta.calendarCadence?.matchReady && career.next); day++) {
   assert.ok(day < 150, 'Aucun jour de match en 150 journées');
   career = settleClubMeetings(good('advance_day', {fromDate: career.meta.calendarToday}), good);
  }
  if (!career.selection.valid) good('auto_lineup');
  let model = skipMatchTalk(good('begin_match'), good);
  let presentation = 0, simulation = 0;
  for (let step = 0; step < 12; step++) {
   const prior = fs.readFileSync(current);
   const priorBackup = fs.readFileSync(backup);
   const priorIdentity = fs.statSync(current, {bigint: true}).ino;
   const priorScene = model.live.scene;
   model = good('tick');
   const after = fs.readFileSync(current);
   const previous = JSON.parse(prior);
   const saved = JSON.parse(after);
   if (saved.seed === previous.seed && isDeepStrictEqual(saved.store, previous.store)) {
    if (!isDeepStrictEqual(model.live.scene, priorScene)) presentation++;
    assert.deepEqual(after, prior, 'Horloge durable conservée pour une image seule');
    assert.equal(fs.statSync(current, {bigint: true}).ino, priorIdentity, 'État identique réécrit');
    assert.deepEqual(fs.readFileSync(backup), priorBackup);
    assert.equal(JSON.parse(good('export').meta.exportText).exportedAt, new Date(previous.clock).toISOString());
   } else {
    simulation++;
    assert.equal(saved.clock, now, 'Une nouvelle décision met à jour l’horloge durable');
    assert.deepEqual(fs.readFileSync(backup), prior);
   }
  }
  assert.ok(presentation > 0 && simulation > 0, 'Le parcours doit exercer les deux types de tick');

  const prior = fs.readFileSync(current);
  const before = good('export');
  const refused = refuseSavePublication(current, () => request('tick', {steps: 12}));
  assert.equal(refused.ok, false);
  assert.deepEqual(refused.model.live.scene, before.live.scene);
  assert.deepEqual(fs.readFileSync(current), prior);
  assert.equal(good('export').meta.exportText, before.meta.exportText);
  good('tick', {steps: 12});
  assert.notDeepEqual(fs.readFileSync(current), prior);
  assert.deepEqual(fs.readFileSync(backup), prior);

  good('pause', {paused: true});
  const paused = fs.readFileSync(current);
  const heldBackup = path.join(dataDir, 'secours-temoin.json');
  fs.renameSync(backup, heldBackup);
  fs.mkdirSync(backup);
  assert.match(request('tick').error, /Écriture de sauvegarde impossible/);
  assert.deepEqual(fs.readFileSync(current), paused);
  fs.rmdirSync(backup);
  good('tick');
  assert.deepEqual(fs.readFileSync(backup), paused, 'Un secours manquant doit être recréé');
  const durable = good('export').meta.exportText;
  good('shutdown');
  bridge = createBridge({dataDir});
  assert.equal(good('export').meta.exportText, durable);
 } finally {
  Date.now = realNow;
  bridge?.close();
  const resolved = fs.realpathSync(dataDir);
  if (path.dirname(resolved) === parent) fs.rmSync(resolved, {recursive: true, force: true});
 }
});
