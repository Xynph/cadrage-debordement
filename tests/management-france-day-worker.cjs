'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

test('Un club français joue un jour à la fois dans le Monde, y compris après le résultat', t => {
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
  let model = settle(good('new_career', { mode: 'world-champ', club: 0 }));
  // Monde : la carrière s'ouvre en préparation d'avant-saison ; le premier match du club (Toulouse) est le 6 septembre.
  const fixture = model.calendar.find(f => f.home.id === 0 || f.away.id === 0);
  const matchDay = fixture.date, dayAfter = n => new Date(Date.parse(matchDay + 'T12:00:00Z') + n * 86400000).toISOString().slice(0, 10);
  assert.equal(model.meta.calendarToday, '2026-07-13');
  assert.equal(matchDay, '2026-09-06');
  assert.equal(model.meta.calendarCadence.preseason, true);
  assert.equal(request('begin_match').ok, false);
  const firstDay = model.meta.calendarToday;
  model = advance(model);
  assert.equal(request('advance_day', { fromDate: firstDay }).ok, false);
  while (!model.meta.calendarCadence.matchReady) model = advance(model);
  assert.equal(model.meta.calendarToday, matchDay);
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
  assert.equal(model.meta.calendarToday, matchDay);
  assert.deepEqual(model.calendar.find(f => f.id === fixture.id).score, score);
  const archive = good('export').meta.exportText;
  const confirmed = JSON.parse(archive).state;
  assert.equal(model.meta.calendarCadence.resultConfirmed, true);
  assert.equal(confirmed.live.finished, true, 'The confirmed live remains evidence until the actual weekly close');
  assert.deepEqual(confirmed.live.score, score);
  assert.equal(confirmed.trained, true);
  bridge.close();
  bridge = createBridge(options);
  assert.equal(good('export').meta.exportText, archive);
  model = advance(good('snapshot'));
  assert.equal(model.meta.calendarToday, dayAfter(1));
  assert.equal(request('finish_round').ok, false);
  model = advance(model);
  assert.equal(model.meta.calendarToday, dayAfter(2));
  assert.equal(model.meta.week, fixture.week + 1);
  assert.equal(model.meta.trained, false, 'Training resets only at the weekly close');
  assert.deepEqual(model.calendar.find(f => f.id === fixture.id).score, score);
  assert.equal(JSON.parse(good('export').meta.exportText).state.live, null);
});
