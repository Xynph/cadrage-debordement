'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

test('Base commune joue un jour à la fois, y compris après le résultat', t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-france-day-'));
  const options = { dataDir: folder, seed: 327, now: 1794178800000, dailyCalendar: true };
  let bridge = createBridge(options);
  let id = 0;
  t.after(() => {
    bridge.close();
    fs.rmSync(folder, { recursive: true, force: true });
  });
  const request = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  function good(command, payload) {
    const result = request(command, payload);
    assert.equal(result.ok, true, result.error);
    return result.model;
  }
  const settle = model => settleClubMeetings(model, good);
  const advance = model => {
    const ready = settle(model);
    return good('advance_day', { fromDate: ready.meta.calendarToday });
  };
  let model = settle(good('new_career', { mode: 'common', club: 0 }));
  assert.equal(model.meta.calendarToday, '2026-09-07');
  assert.equal(model.calendarPlanning.simulatedDates, true);
  assert.equal(model.next.date, '2026-09-12');
  assert.equal(request('begin_match').ok, false);
  const firstDay = model.meta.calendarToday;
  model = advance(model);
  assert.equal(request('advance_day', { fromDate: firstDay }).ok, false);
  while (!model.meta.calendarCadence.matchReady) model = advance(model);
  assert.equal(model.meta.calendarToday, '2026-09-12');
  assert.equal(request('advance_day', { fromDate: model.meta.calendarToday }).ok, false);
  model = good('begin_match');
  assert.equal(model.clubLife.matchTalks.scene.phase, 'pre');
  skipMatchTalk(model, good);
  model = good('delegate');
  assert.equal(model.live.finished, true);
  const score = model.live.score;
  model = good('finish_round');
  assert.equal(model.live, null);
  assert.equal(model.next, null);
  assert.equal(model.meta.calendarToday, '2026-09-12');
  assert.deepEqual(model.calendar.find(f => f.week === model.meta.week).score, score);
  const archive = good('export').meta.exportText;
  const confirmed = JSON.parse(archive).state;
  assert.equal(confirmed.franceCalendar.resultConfirmed, true);
  assert.equal(confirmed.live.finished, true, 'The confirmed live remains evidence until the actual weekly close');
  assert.deepEqual(confirmed.live.score, score);
  assert.equal(confirmed.trained, true);
  bridge.close();
  bridge = createBridge(options);
  assert.equal(good('export').meta.exportText, archive);
  model = advance(good('snapshot'));
  assert.equal(model.meta.calendarToday, '2026-09-13');
  assert.equal(request('finish_round').ok, false);
  model = advance(model);
  assert.equal(model.meta.calendarToday, '2026-09-14');
  assert.equal(model.meta.week, 1);
  assert.equal(model.meta.trained, false, 'Training resets only at the weekly close');
  assert.deepEqual(model.calendar.find(f => f.week === 0).score, score);
  assert.equal(JSON.parse(good('export').meta.exportText).state.live, null);
});
