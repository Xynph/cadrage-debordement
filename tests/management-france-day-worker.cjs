'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');

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
  const advance = model => good('advance_day', { fromDate: model.meta.calendarToday });
  let model = good('new_career', { mode: 'common', club: 0 });
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
  good('begin_match');
  model = good('delegate');
  assert.equal(model.live.finished, true);
  const score = model.live.score;
  model = good('finish_round');
  assert.equal(model.live, null);
  assert.equal(model.next, null);
  assert.equal(model.meta.calendarToday, '2026-09-12');
  assert.deepEqual(model.calendar.find(f => f.week === model.meta.week).score, score);
  const archive = good('export').meta.exportText;
  bridge.close();
  bridge = createBridge(options);
  assert.equal(good('export').meta.exportText, archive);
  model = advance(good('snapshot'));
  assert.equal(model.meta.calendarToday, '2026-09-13');
  assert.equal(request('finish_round').ok, false);
  model = advance(model);
  assert.equal(model.meta.calendarToday, '2026-09-14');
  assert.equal(model.meta.week, 1);
  assert.deepEqual(model.calendar.find(f => f.week === 0).score, score);
});
