'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const callups = require('../native/engine/international-callups.cjs');
const date = '2027-02-05';
const historical = { seniorCaps: 5, seniorNation: 'FRA' };

test('senior duty uses a deterministic reserve pool for a complete, qualified XV and bench', () => {
 const pool = callups.nationalReservePool('FRA', 80, 30);
 const real = [
  { id: 'lnr:left', fam: 0, pos: 'Pilier gauche', rating: 55, age: 22, condition: 100, eligible: 'FRA' },
  { id: 'lnr:right', fam: 0, pos: 'Pilier droit', rating: 95, age: 22, injury: 2, eligible: 'FRA' },
  { id: 'lnr:other', fam: 0, pos: 'Pilier droit', rating: 94, age: 22, eligible: 'ITA', lnrNationality: 'France' },
  { id: 'lnr:unreleased', fam: 0, pos: 'Pilier droit', rating: 93, age: 22, eligible: 'FRA' },
 ];
 const select = players => callups.selectCallups({
  players, nation: 'FRA', date, size: 30,
  isEligible: (p, nation) => p.eligible === nation,
  unavailableIds: ['lnr:unreleased'],
 });
 const players = real.concat(pool);
 const calledIds = select(players);
 assert.deepEqual(calledIds, select(players.slice().reverse()));
 assert.equal(calledIds.length, 30);
 assert.deepEqual(calledIds.filter(id => id.startsWith('lnr:')), ['lnr:left']);

 const sheet = callups.selectInternationalSheet({ players, calledIds });
 assert.equal(sheet.complete, true);
 assert.equal(sheet.lineup[0], 'lnr:left');
 assert.equal(new Set([...sheet.lineup, ...sheet.reserves]).size, 23);
 const positions = new Map(players.map(p => [p.id, p.pos]));
 assert.deepEqual([sheet.lineup[0], sheet.lineup[1], sheet.lineup[2], ...sheet.reserves.slice(0, 3)].map(id => positions.get(id)), [
  'Pilier gauche', 'Talonneur', 'Pilier droit', 'Talonneur', 'Pilier gauche', 'Pilier droit',
 ]);
});

test('a versatile first row can cover a scarce slot without overriding a valid selected preference', () => {
 const pool = callups.nationalReservePool('SCO', 65, 23);
 const lefts = pool.filter(p => p.pos === 'Pilier gauche');
 const rights = pool.filter(p => p.pos === 'Pilier droit');
 const versatile = { ...lefts[0], id: 'versatile', nationalReserve: false, nationaleQualifications: ['Pilier droit'] };
 const onlyLeft = { ...lefts[0], id: 'only-left', nationalReserve: false };
 const players = [...pool.filter(p => p !== lefts[0] && p !== rights[0]), versatile, onlyLeft];
 const sheet = callups.selectInternationalSheet({ players, calledIds: players.map(p => p.id), preferredLineup: ['only-left'] });
 assert.equal(sheet.complete, true);
 assert.equal(sheet.lineup[0], 'only-left');
 assert.ok([sheet.lineup[2], sheet.reserves[2]].includes('versatile'));
});

test('a fixture lineup cannot award caps without play, to an unused reserve, or twice after reloading', () => {
 const appearances = [];
 const lineup = Array.from({ length: 15 }, (_, index) => `starter-${index}`);
 const reserves = ['replacement', 'unused'];
 const match = { fixtureId: 'six-nations-2027-1-fra-ire', date, nation: 'FRA', lineup, reserves, playedIds: [...lineup, 'replacement'] };
 assert.equal(callups.recordInternationalAppearances(appearances, match), false);
 assert.deepEqual(callups.internationalCaps(appearances, lineup[0], historical), { career: 0, total: 5, nation: 'FRA' });
 assert.equal(callups.recordInternationalAppearances(appearances, { ...match, completed: true }), true);
 const loaded = JSON.parse(JSON.stringify(appearances));
 assert.equal(callups.validateInternationalAppearances(loaded), true);
 assert.equal(callups.recordInternationalAppearances(loaded, { ...match, completed: true }), false);
 assert.deepEqual(callups.internationalCaps(loaded, lineup[0], historical), { career: 1, total: 6, nation: 'FRA' });
 assert.deepEqual(callups.internationalCaps(loaded, 'replacement'), { career: 1, total: 1, nation: 'FRA' });
 assert.deepEqual(callups.internationalCaps(loaded, 'unused'), { career: 0, total: 0, nation: null });
 assert.throws(() => callups.recordInternationalAppearances(loaded, {
  ...match, completed: true, playedIds: [...lineup, 'illegal-player'],
 }));
 assert.throws(() => callups.recordInternationalAppearances(loaded, {
  ...match, completed: true, nation: 'IRE',
 }));
 assert.equal(callups.validateInternationalAppearances([...loaded, ...loaded]), false);
 assert.deepEqual(loaded, appearances);
});

test('Six Nations gaps give club availability back and the World Cup uses its opening date', () => {
 const fixtures = [date, '2027-02-14', '2027-02-20', '2027-03-06', '2027-03-13'].map(date => ({ date }));
 const periods = callups.releasePeriods(fixtures);
 assert.deepEqual(periods, [
  { from: '2027-01-30', through: '2027-02-21' },
  { from: '2027-02-28', through: '2027-03-14' },
 ]);
 const calls = periods.map(period => ({ ...period, nation: 'FRA', playerIds: ['p'] }));
 assert.equal(callups.clubReleaseOn(calls, 'p', '2027-01-29'), null);
 assert.deepEqual(callups.clubReleaseOn(calls, 'p', date), calls[0]);
 assert.equal(callups.clubReleaseOn(calls, 'p', '2027-02-27'), null);
 assert.equal(callups.clubReleaseOn(calls, 'p', '2027-03-15'), null);
 assert.deepEqual(callups.releasePeriods([{ date: '2027-10-03' }, { date: '2027-10-17' }], {
  worldCup: true, openingDate: '2027-10-01',
 }), [{ from: '2027-08-26', through: '2027-10-18' }]);
});
