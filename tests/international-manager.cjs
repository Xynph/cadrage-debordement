'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const roles = require('../native/engine/international-manager.cjs');
const supportedNations = ['FRA', 'IRE', 'SCO'];
const start = '2026-07-01';
const date = '2027-01-15';
const context = { supportedNations, date };

test('career creation supports club, selection or a dual role', () => {
 assert.deepEqual(roles.managerRole(), { mode: 'club', club: true, nation: null });
 for (const [mode, nation, club] of [['club', null, true], ['nation', 'FRA', false], ['dual', 'SCO', true]]) {
  const role = roles.createManagerRole({ mode, nation, date: start }, supportedNations);
  assert.deepEqual(roles.managerRole(role), { mode, club, nation });
  assert.equal(roles.validateManagerRole(JSON.parse(JSON.stringify(role)), context), true);
 }
 assert.throws(() => roles.createManagerRole({ mode: 'nation', nation: 'XXX', date }, supportedNations));
 assert.throws(() => roles.createManagerRole({ mode: 'club', nation: 'FRA', date }, supportedNations));
});

test('a dated national offer can add or replace the current club role', () => {
 const clubRole = roles.createManagerRole({ mode: 'club', date: start }, supportedNations);
 const request = { mode: 'dual', nation: 'FRA', date, fromMode: 'club', fromNation: null };
 const prior = JSON.stringify(clubRole);
 assert.deepEqual(roles.nationalOffers(clubRole, supportedNations), ['FRA', 'IRE', 'SCO']);
 assert.throws(() => roles.applyManagerRole(clubRole, request, context));
 const withOffer = { ...context, nationalOffer: 'FRA' };
 assert.throws(() => roles.applyManagerRole(clubRole, request, { ...withOffer, matchInProgress: true }));
 assert.throws(() => roles.applyManagerRole(clubRole, { ...request, date: '2027-01-16' }, withOffer));
 const dual = roles.applyManagerRole(clubRole, request, withOffer);
 assert.deepEqual(roles.managerRole(dual), { mode: 'dual', club: true, nation: 'FRA' });
 assert.equal(JSON.stringify(clubRole), prior);
 assert.throws(() => roles.applyManagerRole(dual, request, withOffer));
 const exclusive = roles.applyManagerRole(dual, { ...request, mode: 'nation', fromMode: 'dual', fromNation: 'FRA' }, context);
 assert.deepEqual(roles.managerRole(exclusive), { mode: 'nation', club: false, nation: 'FRA' });
 assert.deepEqual(roles.nationalOffers(exclusive, supportedNations), ['IRE', 'SCO']);
 assert.deepEqual(exclusive.history, [{ club: true, nation: null, since: start }, { club: true, nation: 'FRA', since: date }]);
 assert.equal(roles.validateManagerRole(exclusive, context), true);
});

test('a selection-only coach must actually take a new club job before gaining club permissions', () => {
 const sole = roles.createManagerRole({ mode: 'nation', nation: 'IRE', date: start }, supportedNations);
 const request = { mode: 'dual', nation: 'IRE', date, fromMode: 'nation', fromNation: 'IRE' };
 assert.throws(() => roles.applyManagerRole(sole, request, context));
 assert.throws(() => roles.applyManagerRole(sole, request, { ...context, clubOffer: { status: 'accepted', clubId: 12 }, activeClubId: 12 }));
 assert.throws(() => roles.applyManagerRole(sole, request, { ...context, clubOffer: { status: 'completed', clubId: 13 }, activeClubId: 12 }));
 const dual = roles.applyManagerRole(sole, request, { ...context, clubOffer: { status: 'completed', clubId: 12 }, activeClubId: 12 });
 assert.deepEqual(roles.managerRole(dual), { mode: 'dual', club: true, nation: 'IRE' });
 const departed = roles.applyManagerRole(dual, { mode: 'club', date, fromMode: 'dual', fromNation: 'IRE' }, context);
 assert.deepEqual(roles.managerRole(departed), { mode: 'club', club: true, nation: null });
});

test('role imports reject forged jobs, future histories and incompatible shapes', () => {
 const role = roles.createManagerRole({ mode: 'nation', nation: 'IRE', date: start }, supportedNations);
 assert.equal(roles.validateManagerRole(undefined, context), true);
 for (const forged of [
  null, { ...role, clubId: 42 }, { ...role, nation: 'XXX' }, { ...role, nation: null },
  { ...role, since: '2027-02-01' }, { ...role, since: '2027-02-30' },
  { ...role, history: [{ club: true, nation: null, since: date }] },
  { ...role, history: [{ club: false, nation: 'IRE', since: start }] },
 ]) assert.equal(roles.validateManagerRole(forged, context), false);
});
