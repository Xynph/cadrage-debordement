'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const competitions = require('../native/engine/international-competitions.cjs');
const callups = require('../native/engine/international-callups.cjs');
const facts = { players: {
  'lnr:hook': { seniorNation: 'FRA', seniorCaps: 12 },
  'lnr:wing': { eligibilityNations: ['FRA', 'WAL'] },
  'lnr:foreign': { nationality: 'France' },
} };
const players = [
  { id: 'lnr:hook', pos: 'Talonneur', fam: 1, rating: 84, age: 29 },
  { id: 'lnr:wing', pos: 'Ailier', fam: 6, rating: 85, age: 25 },
  { id: 'lnr:foreign', pos: 'Arrière', fam: 8, rating: 96, age: 27, lnrNationality: 'France' },
];
const create = () => require('../native/engine/international-career.cjs').createInternationalCareer(competitions, callups, facts);
const advance = (game, state, to, overrides = {}) => game.advance(state, {
  from: state.date, to, players, clubPlayerIds: ['lnr:hook'], managedNation: 'FRA', ...overrides,
});
const project = (game, state, managedNation = 'FRA') => game.project(state, { date: state.date, players, managedNation });
const core = id => !competitions.EXTRA_FAMILIES.some(family => id.startsWith(family + '-'));
const coreResults = results => Object.fromEntries(Object.entries(results).filter(([id]) => core(id)));
const coreCount = state => Object.values(state.results).reduce((count, season) => count + Object.keys(season).filter(core).length, 0);
const resultCount = state => Object.values(state.results).reduce((count, season) => count + Object.keys(season).length, 0);

test('opens camp once, warns only for the managed nation and own club and blocks skipping its match', () => {
  const game = create();
  const initial = game.initial('2026-12-01', 42);
  const opening = advance(game, initial, '2027-01-31');
  const france = opening.state.callups.find(camp => camp.nation === 'FRA');
  assert.equal(france.from, '2027-01-31');
  assert.ok(france.playerIds.includes('lnr:hook'));
  assert.ok(!france.playerIds.includes('lnr:foreign'));
  assert.equal(opening.mail.filter(item => item.nation === 'FRA').length, 2);
  assert.ok(opening.mail.every(item => item.action === 'international'));
  assert.deepEqual(advance(game, opening.state, '2027-01-31').mail, []);
  const before = JSON.stringify(opening.state);
  assert.throws(() => advance(game, opening.state, '2027-02-07'), /match international/i);
  assert.equal(JSON.stringify(opening.state), before);
  assert.equal(game.validate(opening.state, { date: '2027-01-31' }), true);
});

test('plays an exact national fixture with real IDs and restores appearances without duplication', () => {
  const game = create();
  const initial = game.initial('2026-12-01', 42);
  const start = advance(game, initial, '2027-02-06').state;
  const model = project(game, start);
  assert.equal(model.currentFixture.id, 'six-nations-2027-r1-3');
  assert.equal(model.currentFixture.result, null);
  assert.equal(model.sheet.complete, true);
  assert.equal(model.sheet.lineup[1], 'lnr:hook');
  assert.ok(model.squad.some(player => player.nationalReserve));
  const payload = { date: start.date, fixtureId: model.currentFixture.id, managedNation: 'FRA', players };
  assert.throws(() => game.play(start, { ...payload, lineup: ['lnr:hook'] }), /composition/i);
  const played = game.play(start, payload);
  assert.equal(played.mail.length, 1);
  const fixture = played.state.appearances.filter(row => row.fixtureId === payload.fixtureId);
  assert.equal(fixture.length, 2);
  assert.equal(fixture.find(row => row.nation === 'FRA').playedIds[1], 'lnr:hook');
  assert.deepEqual(callups.internationalCaps(played.state.appearances, 'lnr:hook', facts.players['lnr:hook']),
    { career: 1, total: 13, nation: 'FRA' });
  const reopened = JSON.parse(JSON.stringify(played.state));
  assert.equal(game.validate(reopened), true);
  assert.deepEqual(game.play(reopened, payload), { state: reopened, mail: [] });
  const end = advance(game, reopened, '2027-02-07').state;
  assert.equal(end.appearances.filter(row => core(row.fixtureId)).length, 6);
  assert.equal(game.validate(end), true);
});

test('replays history without backdated mail or caps and resumes inside a live camp', () => {
  const game = create();
  const historical = game.initial('2027-11-14', 42);
  assert.equal(coreCount(historical), 121);
  assert.deepEqual(historical.appearances, []);
  assert.deepEqual(historical.callups, []);
  assert.equal(game.validate(historical), true);
  const editions = project(game, historical).competitions;
  assert.ok(editions.filter(edition => edition.year <= 2027).every(edition => edition.outcome.complete));
  assert.ok(editions.some(edition => edition.id === 'six-nations-2028' && !edition.outcome.complete));
  assert.deepEqual(advance(game, historical, '2027-11-16').mail, []);
  const active = game.initial('2027-02-06', 42);
  const model = project(game, active);
  assert.equal(model.sheet.lineup[1], 'lnr:hook');
  assert.deepEqual(active.callups, []);
  assert.deepEqual(active.appearances, []);
});

test('simulates all editions identically across one long advance and calendar boundaries', () => {
  const game = create();
  const initial = game.initial('2026-07-01', 42);
  const options = { managedNation: null };
  const end = advance(game, initial, '2027-11-15', options).state;
  const dates = ['2027-01-30', '2027-02-06', '2027-03-01', '2027-03-16', '2027-08-26', '2027-10-17', '2027-10-19', '2027-11-15'];
  const progressive = dates.reduce((state, date) => advance(game, state, date, options).state, initial);
  assert.deepEqual(progressive, end);
  assert.equal(coreCount(end), 121);
  assert.equal(end.appearances.filter(row => core(row.fixtureId)).length, 242);
  assert.equal(game.validate(end), true);
  const cup = project(game, end).competitions.find(edition => edition.id === 'rugby-world-cup-2027');
  const champion = cup.outcome.winnerIds[0];
  assert.equal(end.callups.find(camp => camp.nation === champion && camp.competitionId === cup.id).through, '2027-11-14');
  assert.ok(end.callups.some(camp => camp.competitionId === cup.id && camp.through < '2027-11-01'));
  const broken = JSON.parse(JSON.stringify(end));
  broken.appearances[0].playedIds[0] = 'unknown-id';
  assert.throws(() => game.validate(broken), /participation/i);
});

test('shows prior Nations Championship matches and catches a national match inside a club season gap', () => {
  const game = create();
  const old = game.initial('2026-08-17', 21);
  const nations = project(game, old).competitions.find(edition => edition.id === 'nations-championship-2026');
  assert.equal(nations.fixtures.filter(fixture => fixture.result).length, 18);
  assert.deepEqual(old.appearances, []);
  const beforeGap = game.initial('2027-06-20', 21);
  assert.throws(() => advance(game, beforeGap, '2027-08-23', { managedNation: 'AUS' }), error =>
    error.code === 'INTERNATIONAL_MATCH_PENDING' && error.date === '2027-07-10' &&
    error.fixtureId.startsWith('rugby-championship-2027-'));
  const onDate = advance(game, beforeGap, '2027-07-10', { managedNation: 'AUS' }).state;
  assert.equal(project(game, onDate, 'AUS').currentFixture.id.startsWith('rugby-championship-2027-'), true);
});

test('restores a version 1 career beyond the World Cup and starts the next Six Nations camp', () => {
  const game = create();
  const historical = game.initial('2027-11-14', 42);
  const legacy = {
    version: 1, date: '2028-01-01', historyBefore: '2027-11-14', seed: 42,
    results: Object.fromEntries(project(game, historical).fixtures.filter(fixture => fixture.result && core(fixture.id)).map(fixture => [fixture.id, fixture.result])),
    appearances: [], callups: [],
  };
  const upgraded = game.upgrade(legacy);
  assert.equal(upgraded.version, 3);
  assert.equal(upgraded.extendedFrom, '2028-01-01');
  assert.equal(game.validate(JSON.parse(JSON.stringify(upgraded))), true);
  const next = project(game, upgraded).nextFixture;
  assert.match(next.id, /^six-nations-2028-/);
  const opening = advance(game, upgraded, next.date);
  assert.equal(opening.mail.filter(item => item.kind === 'international_callup' && item.nation === 'FRA').length, 1);
  const fixture = project(game, opening.state).currentFixture;
  assert.equal(fixture.id, next.id);
  assert.throws(() => advance(game, opening.state, '2028-03-20'), { code: 'INTERNATIONAL_MATCH_PENDING' });
  const played = game.play(opening.state, {date: fixture.date, fixtureId: fixture.id, managedNation: 'FRA', players});
  assert.equal(game.validate(JSON.parse(JSON.stringify(played.state))), true);
});

test('upgrades a legacy career already far beyond the old schedule without retrospective selections', () => {
  const game = create();
  const legacy = game.initial('2027-11-14', 42);
  const state = game.upgrade({
    version: 1, date: '2057-02-20', historyBefore: legacy.historyBefore, seed: legacy.seed,
    results: coreResults(Object.assign({}, ...Object.values(legacy.results))), appearances: [], callups: [],
  });
  assert.equal(state.recurringFrom, '2057-02-20');
  assert.ok(Object.keys(state.results['2057']).length > 0);
  assert.ok(!state.results['2028']);
  assert.deepEqual(state.appearances, []);
  assert.deepEqual(state.archivedCaps, {});
  assert.ok(project(game, state).nextFixture.date > state.date);
  assert.equal(game.validate(state), true);
  assert.throws(() => game.validate({ ...state, date: '9999-02-20' }), /historique international/i);
});

test('keeps seasons playable and retains cumulative caps while bounding the detailed save history', () => {
  const game = create();
  const start = game.initial('2027-01-31', 42);
  const options = { managedNation: null };
  const through = '2057-01-02';
  const years = Array.from({ length: 30 }, (_, i) => (2028 + i) + '-01-02');
  const stepped = years.reduce((state, date) => advance(game, state, date, options).state, start);
  assert.deepEqual(stepped, advance(game, start, through, options).state);
  const reopened = JSON.parse(JSON.stringify(stepped));
  assert.equal(game.validate(reopened), true);
  assert.ok(resultCount(reopened) > 1600);
  assert.ok(reopened.results['2031']['rugby-world-cup-2031-final']);
  assert.ok(!Object.keys(reopened.results['2030']).some(id => id.startsWith('rugby-championship-')));
  assert.ok(reopened.appearances.length < 300);
  assert.ok(reopened.callups.length < 150);
  assert.ok(Buffer.byteLength(JSON.stringify(reopened)) < 1_000_000);
  const caps = callups.internationalStatus(reopened).caps.get('lnr:hook');
  assert.ok(caps.career > 150);
  assert.equal(caps.nation, 'FRA');
  // La Géorgie joue désormais chaque année (Rugby Europe Championship, tests).
  assert.ok(project(game, reopened, 'GEO').nextFixture.date.startsWith('2057-'));
});
