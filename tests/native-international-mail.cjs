'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const createNativeInternational = require('../native/engine/international-native.cjs');

const player = { id: 'lnr:hook', name: 'Joueur de référence', pos: 'Talonneur', fam: 1, age: 29, rating: 85, condition: 100, injury: 0 };
const facts = { nations: { FRA: ['France', 'fr'] }, players: { [player.id]: { seniorNation: 'FRA', seniorCaps: 5 } } };
const dateAfter = date => new Date(Date.parse(date) + 86400000).toISOString().slice(0, 10);

function bridge({ date = '2027-01-30', opening = '2027-08-16', phase = 'league', profile } = {}) {
 const ctx = vm.createContext({
  S: { club: 0, clubs: [{ id: 0, players: [player] }], phase, worldMode: { day: 0 }, ...(profile ? { national: profile } : {}) },
  CDWorldCareer: { active: () => true, calendarToday: () => date, nextOpening: () => opening },
  roleNote: p => p.rating,
 });
 const international = createNativeInternational(source => vm.runInContext(source, ctx), ctx, facts, true);
 international.initialize(42, { nationalRole: 'dual', nation: 'FRA' });
 return {
  read: international.read,
  advance() {
   international.advance(international.read().career.date);
   if (phase !== 'ended') date = dateAfter(date);
  },
  project() {
   const model = { club: { id: 0 }, meta: { calendarToday: date, canAdvanceSeason: phase === 'ended' } };
   international.project(model);
   return model;
  },
  play(fixture) { international.command('national_play_match', { fromDate: fixture.date, fixtureId: fixture.id }); },
  checkSeason: international.checkSeason,
 };
}

test('international mail explains the camp and records the club return exactly once after reloading', () => {
 const initial = bridge();
 initial.advance();
 const released = initial.read().mail.find(mail => mail.kind === 'international_release');
 assert.equal(released.nation, 'FRA');
 assert.equal(released.action, 'international');
 assert.match(released.body, /Tournoi des Six Nations 2027/);
 assert.match(released.body, /31 janvier 2027/);
 assert.match(released.body, /février 2027/);
 const camp = initial.read().mail.find(mail => mail.kind === 'international_callup');
 assert.match(camp.body, /30 joueurs/);
 assert.equal(camp.date, released.date);

 while (initial.read().career.date < '2027-02-06') initial.advance();
 const first = initial.project().international.currentManagedFixture;
 assert.equal(first.date, '2027-02-06');
 const before = initial.read();
 assert.throws(() => initial.advance(), /Jouez votre match international/);
 assert.deepEqual(initial.read(), before);
 initial.play(first);
 assert.equal(initial.read().mail.filter(mail => mail.kind === 'international_result').length, 1);

 const saved = JSON.parse(JSON.stringify(initial.read()));
 const reopened = bridge({ date: saved.career.date, profile: saved });
 assert.deepEqual(reopened.read(), saved);
 while (reopened.read().career.date < '2027-02-26') {
  const fixture = reopened.project().international.currentManagedFixture;
  if (fixture) reopened.play(fixture);
  reopened.advance();
 }
 const returns = reopened.project().international.mail.filter(mail => mail.kind === 'international_return');
 assert.equal(returns.length, 1);
 assert.equal(returns[0].nation, 'FRA');
 assert.equal(returns[0].action, 'international');
 assert.match(returns[0].body, /joueur revient du rassemblement/);
 assert.match(returns[0].body, /Tournoi des Six Nations 2027/);
 const afterReturn = JSON.parse(JSON.stringify(reopened.read()));
 const again = bridge({ date: afterReturn.career.date, profile: afterReturn });
 assert.deepEqual(again.project().international.mail.filter(mail => mail.kind === 'international_return'), returns);
 again.advance();
 assert.deepEqual(again.project().international.mail.filter(mail => mail.kind === 'international_return'), returns);
});

test('a closed club season retains the international date at the next opening after 2027', () => {
 const initial = bridge({ date: '2028-07-16', opening: '2028-07-18', phase: 'ended' });
 assert.throws(() => initial.checkSeason(), /Terminez les journées/);
 initial.advance();
 assert.equal(initial.project().meta.calendarToday, '2028-07-17');
 assert.equal(initial.project().meta.canAdvanceSeason, false);
 initial.advance();
 const atOpening = initial.project();
 assert.equal(atOpening.meta.calendarToday, '2028-07-18');
 assert.equal(atOpening.meta.canAdvanceSeason, true);
 assert.equal(atOpening.meta.calendarCadence.canAdvance, false);
 assert.doesNotThrow(() => initial.checkSeason());
 const saved = initial.read();
 const reopened = bridge({ date: '2028-07-16', opening: '2028-07-18', phase: 'ended', profile: saved });
 assert.deepEqual(reopened.read(), saved);
 assert.equal(reopened.project().meta.calendarToday, '2028-07-18');
 assert.throws(() => reopened.advance(), /Commencez la saison suivante/);
});
