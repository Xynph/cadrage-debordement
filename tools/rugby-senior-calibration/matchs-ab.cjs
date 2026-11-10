'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { createBridge } = require('../../native/engine/worker.cjs');
const { prepare } = require('./prototype.cjs');

const [clubId, seedList, overridesFile, evidenceRoot, fixedOpener] = process.argv.slice(2);
const club = Number(clubId), seeds = seedList?.split(',').map(Number);
assert.ok(Number.isInteger(club) && seeds?.length && seeds.every(Number.isSafeInteger) && overridesFile && evidenceRoot,
  'Usage : matchs-ab.cjs club graines dérogations dossier-preuves [ouvreur-isolé]');
const overrides = JSON.parse(fs.readFileSync(overridesFile, 'utf8'));
assert.ok(!fixedOpener || Object.hasOwn(overrides, fixedOpener), 'Dossier de l’ouvreur absent');
const root = fs.mkdtempSync(path.join(path.resolve(evidenceRoot), fixedOpener ? 'ouvreurs-' : 'matchs-' + club + '-'));
const sha = buffer => crypto.createHash('sha256').update(buffer).digest('hex');
const worker = require.resolve('../../native/engine/worker.cjs');
const node = process.execPath;
const now = 1794300000000;
const stateOf = envelope => JSON.parse(envelope.store['bdt-v1']);
let serial = 0;

function open(dataDir, run) {
  const bridge = createBridge({ dataDir, seed: 20261110, now });
  const ask = (command, payload = {}) => {
    const response = bridge.handle({ id: ++serial, command, payload });
    assert.equal(response.ok, true, command + ' : ' + response.error);
    assert.equal(response.model.meta.profileError, '');
    return response.model;
  };
  try {
    return run(ask);
  } finally {
    bridge.close();
  }
}

const reference = open(path.join(root, 'reference'), ask => {
  const model = ask('new_career', { mode: 'world-champ', club });
  assert.equal(model.club.id, club);
  return path.join(model.meta.dataDir, 'donnees.json');
});
const original = fs.readFileSync(reference);
const envelope = JSON.parse(original);
const base = stateOf(envelope);
const calibrated = prepare(base, fixedOpener ? { [fixedOpener]: overrides[fixedOpener] } : overrides, !fixedOpener);
const league = Object.entries(base.worldMode.leagues).find(([, value]) => value.members.includes(club))?.[0];
const opener = Object.keys(overrides)[0];
const preparation = {
  srp: 'advance_pacific_preparation',
  'jlo-d1': 'advance_japan_preparation',
  'jlo-d2': 'advance_japan_preparation',
  champ: 'advance_champ_preparation',
}[league];

function play(label, seed, state) {
  const dataDir = path.join(root, label + '-' + seed);
  const profile = path.join(dataDir, 'PrototypeGodot');
  fs.mkdirSync(profile, { recursive: true });
  const save = path.join(profile, 'donnees.json');
  fs.writeFileSync(save, JSON.stringify({ ...envelope, seed, store: { ...envelope.store, 'bdt-v1': JSON.stringify(state) } }), { flag: 'wx' });
  const read = () => stateOf(JSON.parse(fs.readFileSync(save)));
  return open(dataDir, ask => {
    let model = ask('snapshot');
    assert.equal(model.club.id, club);
    while (!model.next && model.meta.week < 46) {
      const week = model.meta.week;
      model = preparation ? ask(preparation, { fromWeek: week }) : ask('finish_round');
      assert.ok(model.meta.week > week);
    }
    assert.ok(model.next, 'Aucune affiche dans la saison');
    const fixture = {
      week: model.meta.week, home: model.next.home.name, away: model.next.away.name,
      date: model.next.date ?? null, pair: model.next.pair,
    };
    model = ask('auto_lineup');
    if (!model.selection.valid) model = ask('promote_cover', { confirmed: true });
    if (fixedOpener) model = ask('set_lineup', { slot: 9, playerId: fixedOpener });
    assert.equal(model.selection.valid, true, JSON.stringify(model.selection.errors));
    const player = model.squad.find(p => p.id === opener);
    const starting = ask('begin_match');
    assert.equal(starting.live.minute, 0);
    const sheets = read().live.sheets.map(({ initial, bench }) => ({ initial, bench }));
    assert.ok(sheets.every(s => s.initial.length === 15 && s.bench.length === 8));
    assert.equal(ask('delegate').live.finished, true);
    const { live } = read();
    if (fixedOpener) assert.ok(live.sheets[live.userSide].minutes[fixedOpener] > 0);
    const finished = ask('finish_round');
    assert.ok(finished.meta.week > fixture.week);
    const persisted = read();
    return {
      fixture, sheets, side: live.userSide,
      opener: player ? { rating: player.rating, note: player.note, shirt: player.shirtNumber, minutes: live.sheets[live.userSide].minutes[opener] ?? 0 } : null,
      score: live.score, tries: live.tries, minute: live.minute, stats: live.stats,
      after: {
        week: finished.meta.week, cash: finished.club.cash, historyLength: persisted.history.length,
        injuries: persisted.clubs[club].players.filter(p => p.injury > 0).length,
        meanCondition: persisted.clubs[club].players.reduce((sum, p) => sum + p.condition, 0) / persisted.clubs[club].players.length,
      },
    };
  });
}

const comparisons = [];
try {
  for (const seed of seeds) {
    const control = play('temoin', seed, base), candidate = play('candidat', seed, calibrated);
    assert.deepEqual(candidate.fixture, control.fixture);
    if (fixedOpener) assert.deepEqual(candidate.sheets, control.sheets);
    comparisons.push({ seed, control, candidate });
    console.log(JSON.stringify({
      league, club, seed, fixture: control.fixture, score: [control.score, candidate.score],
      starterChanges: control.sheets.map((s, side) => s.initial.filter((id, i) => id !== candidate.sheets[side].initial[i]).length),
      opener: [control.opener, candidate.opener], week: candidate.after.week,
    }));
  }
  assert.deepEqual(fs.readFileSync(reference), original);
} finally {
  fs.writeFileSync(path.join(root, 'rapport.json'), JSON.stringify({
    root, worker, workerSha256: sha(fs.readFileSync(worker)), node, league, club, fixedOpener, sourceSha256: sha(original), comparisons,
  }, null, 2));
  console.log(root);
}
