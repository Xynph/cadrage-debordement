'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {createBridge} = require(path.resolve('native/engine/worker.cjs'));
const bridge = createBridge({dataDir:process.argv[2], seed:713492, dailyCalendar:true, mandatoryPress:true, internationalCareer:true});
let id = 0;
function request(command, payload = {}) {
  const response = bridge.handle({id:++id, command, payload});
  assert.equal(response.ok, true, command + ' ' + JSON.stringify(payload) + ' ' + response.error);
  return response.model;
}
try {
  let model = request('new_career', {mode:'world-champ',nationalRole:'nation',nation:'FRA'});
  for (let days = 0; !model.international.currentManagedFixture && days < 100; days++) {
    const date = model.meta.calendarToday;
    model = request('advance_day', {fromDate:date});
    if (days % 7 === 0) console.log(model.meta.calendarToday);
  }
  const fixture = model.international.currentManagedFixture;
  assert.equal(fixture?.date, '2026-11-07');
  assert.equal(fixture.homeId, 'FRA');
  assert.equal(fixture.awayId, 'FIJ');
  assert.ok(model.international.mail.some(mail => mail.kind === 'international_match'));
  console.log(fixture.date, fixture.id, fixture.homeId, fixture.awayId);
  request('shutdown');
} finally {
  bridge.close();
}
