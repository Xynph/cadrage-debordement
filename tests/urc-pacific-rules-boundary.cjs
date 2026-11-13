'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createBridge} = require('../native/engine/worker.cjs');
const C = require('../native/engine/world-competitions.cjs').factory();
const ledger = require('../native/engine/srp-calendar-2027.json');
const P = require('../native/engine/super-rugby-pacific.cjs').factory(ledger);

// Existing srp-world-calendar covers a VM-only synthetic initial calendar.
// This case exercises the public worker, private disk/RNG and resumed continuation.
// The shipped anonymous catalogue is used with disposable, seeded careers only.
test('Pacifique : reprise disque et continuation déterministes sans changement de frontière réglementaire', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-urc-pacific-boundary-'));
  const profile = path.join(root, 'PrototypeGodot');
  const file = path.join(profile, 'donnees.json');
  let bridge, serial = 0;
  const open = seed => createBridge({dataDir: profile, seed, now: 1794178800000});
  const raw = (command, payload = {}) => bridge.handle({id: ++serial, command, payload});
  const go = (command, payload = {}) => {
    const result = raw(command, payload);
    assert.equal(result.ok, true, command + ': ' + result.error);
    return result.model;
  };
  const state = () => JSON.parse(go('export').meta.exportText).state;
  function boundary(model, save) {
    assert.equal(model.meta.edition, 'world-pacific');
    assert.equal(model.meta.rulesProfile, 'world-pro-2026-27-srp-2027-v2');
    assert.match(model.meta.competitionRules, /2026–2027.*Pacifique 2027/);
    assert.equal(save.worldMode.startYear, 2026);
    const srp = save.worldMode.fixtures.filter(f => f.competitionId === 'srp');
    assert.equal(srp.length, 80);
    assert.equal(new Set(srp.map(f => f.id)).size, 80);
    assert(srp.every(f => f.date.startsWith('2027-') && f.scheduleSource === 'official-2027-draw'));
    const members = save.worldMode.leagues.srp.members;
    assert.equal(members.length, 10);
    for (const id of members) assert.equal(srp.filter(f => f.homeId === id || f.awayId === id).length, 16);
    for (const cup of ['champions', 'challenge']) {
      assert(save.worldMode.europe[cup].pools.flat().every(id => !members.includes(id)));
      assert(save.worldMode.fixtures.filter(f => f.competitionId === cup)
        .every(f => !members.includes(f.homeId) && !members.includes(f.awayId)));
    }
    // The projection must preserve uncertainty rather than invent discipline data.
    const urc = model.leagues.find(l => l.id === 'urc');
    assert.equal(urc.rows.length, 16);
    assert(urc.rows.every(row => row.played === 0 && row.points === 0 && row.unresolvedTie));
  }
  try {
    bridge = open(827381);
    const initialModel = settleClubMeetings(go('new_career', {mode: 'world-pacific', club: 58}),(command,payload)=>go(command,payload));
    const exported = go('export').meta.exportText;
    const initialState = JSON.parse(exported).state;
    boundary(initialModel, initialState);
    const beforeRead = fs.readFileSync(file);
    go('snapshot'); go('snapshot');
    assert.deepEqual(fs.readFileSync(file), beforeRead, 'consultation pure, y compris RNG et horloge privés');

    // Stale commands are refused atomically even in this later world edition.
    assert.equal(raw('advance_pacific_preparation', {fromWeek: 1}).ok, false);
    assert.deepEqual(fs.readFileSync(file), beforeRead);
    go('import', {text: exported});
    assert.deepEqual(state(), initialState, 'réimport public conservant chaque champ de carrière');
    const checkpoint = fs.readFileSync(file);
    const checkpointData = JSON.parse(checkpoint);
    go('shutdown');

    bridge = open(7); // A different proposed seed must lose to the stored RNG.
    boundary(go('snapshot'), state());
    assert.deepEqual(state(), initialState);
    settleClubMeetings(go('finish_round'),(command,payload)=>go(command,payload));
    const firstContinuation = state();
    const firstDisk = JSON.parse(fs.readFileSync(file));
    assert.notEqual(firstDisk.seed, checkpointData.seed, 'la continuation exerce réellement le RNG');
    assert.equal(firstContinuation.round, initialState.round + 1);
    assert(firstContinuation.history.length > initialState.history.length, 'de vrais matchs des autres ligues ont été simulés');
    go('shutdown');

    // Restore only our complete disposable checkpoint, with no active worker.
    fs.writeFileSync(file, checkpoint);
    bridge = open(999999);
    settleClubMeetings(go('finish_round'),(command,payload)=>go(command,payload));
    assert.deepEqual(state(), firstContinuation, 'même continuation complète après restauration/reprise');
    assert.deepEqual(JSON.parse(fs.readFileSync(file)), firstDisk, 'même profil, curseur RNG et horloge compris');
    boundary(go('snapshot'), state());
  } finally {
    bridge?.close();
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('Calendrier confirmé ne signifie pas règles de match confirmées pour la nouvelle saison', () => {
  const urc = C.rules('urc').provenance;
  assert.equal(urc.edition, '2025/26');
  assert.equal(urc.status, 'provisional-current-edition-unavailable');
  assert.equal(urc.corroboration.edition, '2026/27');
  const pacific = P.rules();
  assert.equal(pacific.formatStatus, 'confirmed-2027');
  assert.equal(pacific.playingPolicyStatus, 'provisional-2026-reference-not-verified-for-2027');
  // Behavioural guard: the 2027 calendar alone cannot opt into 2026 match rules.
  assert.throws(() => P.resultPoints([20, 20], [3, 0]), /politique.*requise/);
  assert.deepEqual(P.resultPoints([20, 20], [3, 0], P.referencePolicy).map(r => r.points), [3, 2]);
  assert.throws(() => P.calendarFixtures({clubs: ledger.clubKeys.map((key, id) => ({key, id})), season: 2028}), /politique.*requise/);
  const generated = P.calendarFixtures({clubs: ledger.clubKeys.map((key, id) => ({key, id})), season: 2028, futurePolicy: P.futurePolicy});
  assert(generated.every(f => f.scheduleSource === 'generated-game-repeat-2027-template' && f.kickoffUtc === null));
});
