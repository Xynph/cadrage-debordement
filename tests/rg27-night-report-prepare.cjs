'use strict';
// Build an actual disposable report checkpoint with the production bridge only.
// No harness VM globals, rewritten projection, handcrafted save or hidden ID.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const [profile, output] = process.argv.slice(2);
assert.ok(profile && output, 'Profil jetable et dossier de preuves requis');
fs.mkdirSync(output, { recursive: true });
const actions = [];
const bridge = createBridge({ dataDir: profile, dailyCalendar: true, mandatoryPress: true,
  internationalCareer: true, seed: 20261111 });
let sequence = 0;
let model;
function go(command, payload = {}) {
  const response = bridge.handle({ id: ++sequence, command, payload });
  actions.push({ id: sequence, command, payload, ok: response.ok, ...(response.error ? { error: response.error } : {}) });
  console.log(JSON.stringify(actions.at(-1)));
  assert.equal(response.ok, true, command + ': ' + response.error);
  model = response.model;
  return model;
}
function settle() { model = settleClubMeetings(model, go); }
function talk(phase) {
  const scene = model.clubLife?.matchTalks?.scene;
  if (!scene) return;
  assert.equal(scene.phase, phase, 'Phase de causerie réelle attendue');
  go('match_talk_continue', { key: scene.key, phase: scene.phase, skip: true });
}
try {
  go('new_career', { mode: 'common', club: 0 });
  settle();
  const candidate = model.clubLife.regenScouting.candidates.find(person => Number.isInteger(person.family) && person.age <= 40);
  assert.ok(candidate, 'Candidat effectivement projeté pour la famille de la mission');
  go('scout_mission', { family: candidate.family, maxAge: 40, budget: 10000000, maxWage: 100000, confirmed: true });
  for (let cycle = 0; cycle < 2; cycle++) {
    settle();
    const week = model.meta.week;
    for (let day = 0; day < 40 && !model.meta.calendarCadence?.matchReady; day++) {
      settle();
      assert.equal(model.meta.calendarCadence?.canAdvance, true, 'Journée réelle disponible avant le match');
      go('advance_day', { fromDate: model.meta.calendarToday });
    }
    assert.equal(model.meta.calendarCadence?.matchReady, true, 'Vrai jour de match atteint');
    settle();
    go('auto_lineup');
    go('begin_match');
    talk('pre');
    go('delegate');
    if (model.clubLife?.matchTalks?.scene) talk('post');
    else if (model.live) go('finish_round');
    settle();
    for (let day = 0; day < 7 && model.meta.week === week; day++) {
      assert.equal(model.meta.calendarCadence?.canAdvance, true, 'Journée restante réelle disponible après le match');
      go('advance_day', { fromDate: model.meta.calendarToday });
      settle();
    }
    assert.ok(model.meta.week > week, 'Semaine clôturée par les seules commandes publiques');
  }
  go('snapshot');
  const reports = model.decisions?.recruitment?.reports || [];
  assert.ok(reports.length > 0 && reports.every(report => typeof report.id === 'string' && report.id), 'Vrais rapports produits après les deux cycles de travail');
  const filename = path.join(profile, 'PrototypeGodot/donnees.json');
  fs.writeFileSync(path.join(output, 'report-preparation.json'), JSON.stringify({
    method: 'production createBridge with public daily-calendar and meeting commands only',
    node: process.version,
    worker_sha256: crypto.createHash('sha256').update(fs.readFileSync(path.resolve(__dirname, '../native/engine/worker.cjs'))).digest('hex'),
    profile_sha256: crypto.createHash('sha256').update(fs.readFileSync(filename)).digest('hex'),
    report_ids: reports.map(report => report.id),
    actual_week: model.meta.week,
    actions,
  }, null, 2));
} finally {
  bridge.close();
  fs.writeFileSync(path.join(output, 'report-preparation-actions.json'), JSON.stringify(actions, null, 2));
}
