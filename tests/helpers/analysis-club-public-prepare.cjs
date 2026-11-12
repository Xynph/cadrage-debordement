'use strict';
// Disposable setup only. Use the same production API/options as the Godot worker
// CLI; never edit a saved state, manufacture a fixture or access engine globals.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { createBridge } = require('../../native/engine/worker.cjs');
const { settleClubMeetings } = require('./club-meetings.cjs');
const [profile, output] = process.argv.slice(2);
assert.ok(profile && output, 'Profil jetable et preuves requis');
fs.mkdirSync(output, { recursive: true });
const started = Date.now();
const actions = [];
const receipt = { method: 'production createBridge/public commands', mode: 'world-champ', club: 29,
  node: process.version, worker_sha256: sha(path.resolve(__dirname, '../../native/engine/worker.cjs')),
  flags: { dailyCalendar: true, mandatoryPress: true, internationalCareer: true }, actions };
function sha(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
let bridge;
let model;
let sequence = 0;
function go(command, payload = {}) {
  const response = bridge.handle({ id: ++sequence, command, payload });
  const action = { id: sequence, command, payload, ok: response.ok,
    date: response.model?.meta?.calendarToday, week: response.model?.meta?.week,
    ...(response.error ? { error: response.error } : {}) };
  actions.push(action);
  fs.appendFileSync(path.join(output, 'public-preparation-actions.jsonl'), JSON.stringify(action) + '\n');
  assert.equal(response.ok, true, command + ': ' + response.error);
  model = response.model;
  return model;
}
function settle() { model = settleClubMeetings(model, go); }
function talk(phase) {
  const scene = model.clubLife?.matchTalks?.scene;
  assert.equal(scene?.phase, phase, 'Phase de causerie réelle attendue');
  assert.equal(scene.options.length, 6, 'Six choix effectivement projetés');
  go('match_talk_continue', { key: scene.key, phase: scene.phase, skip: true });
  assert.ok(model.clubLife?.matchTalks?.scene == null, 'Causerie effectivement traitée');
}
try {
  const rawSeed = process.env.CD_GODOT_SEED;
  const options = { dataDir: profile, ...receipt.flags };
  if (rawSeed !== undefined) {
    const seed = Number(rawSeed);
    assert.ok(/^(0|[1-9]\d*)$/.test(rawSeed) && Number.isInteger(seed) && seed >= 0 && seed <= 0xffffffff,
      'Même domaine de seed que le worker CLI');
    options.seed = seed;
    receipt.seed = seed;
  }
  bridge = createBridge(options);
  go('new_career', { mode: 'world-champ', club: 29 });
  receipt.start_date = model.meta.calendarToday;
  settle();
  // advance_day performs the real scheduled training. No extra train command:
  // the graphical setup being replaced never issued one either.
  for (let day = 0; day < 40; day++) {
    settle();
    if (model.meta.calendarCadence?.matchReady) break;
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'Journée réellement autorisée');
    go('advance_day', { fromDate: model.meta.calendarToday });
  }
  assert.equal(model.meta.calendarCadence?.matchReady, true, 'Jour de match atteint en quarante journées maximum');
  assert.ok(model.next, 'Rencontre réellement projetée');
  go('auto_lineup');
  go('begin_match');
  talk('pre');
  go('delegate');
  if (model.clubLife?.matchTalks?.scene) talk('post');
  else if (model.live) go('finish_round');
  settle();
  const completedWeek = model.meta.week;
  for (let day = 0; day < 7 && model.meta.week === completedWeek; day++) {
    settle();
    if (model.meta.week !== completedWeek) break;
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'Clôture quotidienne réellement autorisée');
    go('advance_day', { fromDate: model.meta.calendarToday });
  }
  settle();
  assert.notEqual(model.meta.week, completedWeek, 'Semaine clôturée par commandes publiques');
  go('snapshot');
  const saved = JSON.parse(fs.readFileSync(path.join(profile, 'PrototypeGodot', 'donnees.json'), 'utf8'));
  const encoded = saved.store?.['bdt-v1'];
  const state = typeof encoded === 'string' ? JSON.parse(encoded) : encoded;
  const results = (state?.history || []).filter(row => row.fixtureId && row.season === state.season && row.pair?.includes(state.club));
  assert.ok(results.length, 'Résultat propre réellement archivé');
  receipt.expected_fixture = results.at(-1).fixtureId;
  receipt.archived_result = Object.fromEntries(['fixtureId', 'season', 'pair', 'score', 'phase', 'week'].map(key => [key, results.at(-1)[key]]));
  receipt.actual_week = model.meta.week;
  receipt.end_date = model.meta.calendarToday;
  receipt.ok = true;
} catch (error) {
  receipt.ok = false;
  receipt.error = error.stack;
  throw error;
} finally {
  if (bridge) bridge.close();
  receipt.elapsed_ms = Date.now() - started;
  const file = path.join(profile, 'PrototypeGodot', 'donnees.json');
  if (fs.existsSync(file)) receipt.profile_sha256 = sha(file);
  fs.writeFileSync(path.join(output, 'public-preparation.json'), JSON.stringify(receipt, null, 2));
}
