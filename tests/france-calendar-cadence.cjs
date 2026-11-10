'use strict';

const assert = require('node:assert/strict');
const {test} = require('node:test');
const makeFranceCalendarCadence = require('../native/engine/france-calendar-cadence.cjs');
const cadence = makeFranceCalendarCadence(state => state.fixture);

function career(overrides = {}) {
  return {
    season: 1,
    phase: 'league',
    franceMode: {version: 1, catalogue: 'france-territories-2026-10-31-v1', week: 0},
    fixture: {fixtureId: 's1-elite-league-0-0'},
    live: null,
    ...overrides,
  };
}

test('la date du calendrier France30 reste celle de la cadence simulée', () => {
  assert.equal(cadence.date(1, 0, 0), '2026-09-07');
  assert.equal(cadence.date(1, 0), '2026-09-12');
  assert.equal(cadence.date(1, 17, 0), '2027-01-04');
  assert.equal(cadence.date(2, 0), '2027-09-11');
  assert.equal(cadence.date(10000, 0), null);
});

test('les anciennes sauvegardes France30 peuvent être lues sans mutation', () => {
  const state = career();
  const original = JSON.stringify(state);
  assert.equal(cadence.project(state), null);
  assert.deepEqual(cadence.project(state, true), {
    calendarToday: '2026-09-07',
    calendarCadence: {day: 0, matchReady: false, canAdvance: true},
  });
  assert.equal(cadence.project({...state, live: {finished: false}}, true).calendarToday, '2026-09-12');
  assert.equal(JSON.stringify(state), original);
  assert.equal(cadence.project({...state, franceMode: undefined}, true), null);
  assert.equal(cadence.project({...state, worldMode: {version: 5}}, true), null);
});

test('le pas du jour refuse une demande périmée et attend le résultat du match', () => {
  const state = career({franceCalendar: {day: 4}});
  assert.throws(() => cadence.advance(state, '2026-09-10'), /date/);
  assert.deepEqual(cadence.advance(state, '2026-09-11'), {closeWeek: false, calendar: {day: 5}});
  state.franceCalendar.day = 5;
  assert.deepEqual(cadence.project(state).calendarCadence, {day: 5, matchReady: true, canAdvance: false});
  assert.throws(() => cadence.advance(state, '2026-09-12'), /rencontre/);
  state.live = {finished: false};
  assert.throws(() => cadence.confirm(state), /terminé/);
  state.live.finished = true;
  assert.deepEqual(cadence.confirm(state), {day: 5, resultConfirmed: true});
  state.franceCalendar = cadence.confirm(state);
  assert.deepEqual(cadence.project(state).calendarCadence, {
    day: 5, matchReady: false, canAdvance: true, resultConfirmed: true,
  });
  assert.throws(() => cadence.confirm(state), /déjà/);
  state.franceCalendar = cadence.advance(state, '2026-09-12').calendar;
  assert.deepEqual(state.franceCalendar, {day: 6, resultConfirmed: true});
  assert.doesNotThrow(() => cadence.validate(state));
  assert.deepEqual(cadence.advance(state, '2026-09-13'), {closeWeek: true, calendar: {day: 0}});
});

test('la semaine de repos se clôt le dimanche sans inventer de résultat', () => {
  const state = career({fixture: null, franceCalendar: {day: 6}});
  assert.deepEqual(cadence.advance(state, '2026-09-13'), {closeWeek: true, calendar: {day: 0}});
  state.phase = 'ended';
  state.franceCalendar = {day: 0};
  assert.doesNotThrow(() => cadence.validate(state));
  assert.deepEqual(cadence.project(state).calendarCadence, {day: 0, matchReady: false, canAdvance: false});
  assert.throws(() => cadence.advance(state, '2026-09-07'), /indisponible/);
});

test('l’import refuse un marqueur de calendrier incompatible', () => {
  const state = career();
  assert.doesNotThrow(() => cadence.validate(state));
  for (const franceCalendar of [
    null, [], {}, {day: 7}, {day: undefined}, {day: '5'}, {day: 5, extra: true}, {day: 5, resultConfirmed: false},
    {day: 5, resultConfirmed: true}, {day: 6}, {day: 3, resultConfirmed: true},
  ]) {
    assert.throws(() => cadence.validate({...state, franceCalendar}), /calendrier/i);
  }
  assert.throws(() => cadence.validate(career({franceCalendar: {day: 3}, live: {finished: false}})), /calendrier/i);
  assert.throws(() => cadence.validate(career({franceCalendar: {day: 1}, phase: 'ended'})), /calendrier/i);
  assert.throws(() => cadence.validate({worldMode: {version: 5}, franceCalendar: {day: 0}}), /calendrier/i);
});
