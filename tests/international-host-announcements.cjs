'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = process.env.OVAL_HOST_QA_ROOT ?? path.join(__dirname, '..');
const engine = file => require(path.join(root, 'native/engine', file));
const competitions = engine('international-competitions.cjs');
const callups = engine('international-callups.cjs');
const { createInternationalCareer } = engine('international-career.cjs');
const nativeInternational = engine('international-native.cjs');
const facts = { nations: { AUS: ['Australie', 'au'], USA: ['États-Unis', 'us'] }, players: {} };
const career = createInternationalCareer(competitions, callups, facts);
const seed = 42;

const shift = (date, days) => new Date(Date.parse(date) + days * 86400000).toISOString().slice(0, 10);
const roundTrip = value => JSON.parse(JSON.stringify(value));
const editionOn = (state, id) => career.project(state).competitions.find(edition => edition.id === id);
const findMail = (mail, id, prefix = 'host') => mail.filter(item => item.id === `${prefix}/${id}`);

function announcement(mail, id, date, country, prefix = 'host') {
  const matching = findMail(mail, id, prefix);
  assert.equal(matching.length, 1, `${prefix}/${id} must be sent once`);
  const [item] = matching;
  assert.match(item.kind, prefix === 'host' ? /^international_host$/ : /^international_host(?:_guide)?$/);
  assert.equal(item.action, 'international');
  assert.equal(item.date, date);
  assert.ok(`${item.title} ${item.body}`.includes(country));
  return item;
}

function checkHost(host) {
  assert.ok(host);
  assert.match(host.announcementDate, /^\d{4}-\d{2}-\d{2}$/);
  assert.ok(host.countries.length);
  for (const country of host.countries) {
    assert.match(country.id, /^[A-Z]{3}$/);
    assert.ok(typeof country.name === 'string' && country.name.length > 0);
    assert.ok(typeof country.capital === 'string' && country.capital.length > 0);
    assert.ok(Array.isArray(country.details) && country.details.every(detail => typeof detail === 'string'));
  }
  assert.equal(new Set(host.countries.map(country => country.id)).size, host.countries.length);
}

function bridge(date, savedProfile) {
  const ctx = vm.createContext({
    S: { club: 0, clubs: [{ id: 0, players: [] }], phase: 'league', worldMode: { day: 0 },
      ...(savedProfile ? { national: savedProfile } : {}) },
    CDWorldCareer: { active: () => true, calendarToday: () => date },
  });
  const native = nativeInternational(source => vm.runInContext(source, ctx), ctx, facts, true);
  native.initialize(seed, { nationalRole: 'club' });
  return {
    read: native.read,
    advance() {
      native.advance(native.read().career.date);
      date = shift(date, 1);
    },
    project() {
      const model = { club: { id: 0 }, meta: { calendarToday: date, canAdvanceSeason: false } };
      native.project(model);
      return model.international;
    },
  };
}

test('the 2027 final reveals the 2031 World Cup host, and the 2028 guide survives save and reload without duplication', () => {
  const id = 'rugby-world-cup-2031';
  const final = competitions.createEdition('rugby-world-cup-2027').fixtures.find(fixture => fixture.phase === 'final');
  const before = career.initial(shift(final.date, -1), seed);
  const matchDay = career.advance(before, { from: before.date, to: final.date });
  assert.deepEqual(findMail(matchDay.mail, id), []);
  assert.equal(editionOn(matchDay.state, id)?.host ?? null, null);

  const after = career.advance(matchDay.state, { from: final.date, to: shift(final.date, 1) });
  const early = editionOn(after.state, id);
  assert.equal(early?.year, 2031, 'the next edition is visible immediately after the final');
  checkHost(early.host);
  assert.deepEqual(early.host.countries.map(country => country.id), ['USA']);
  const date = early.host.announcementDate;
  assert.equal(date.slice(0, 4), '2028');
  assert.equal(date.slice(4), competitions.createEdition(id).fixtures[0].date.slice(4));
  const country = early.host.countries[0].name;
  announcement(after.mail, id, final.date, country);
  assert.deepEqual(findMail(after.mail, id, 'host-guide'), []);

  const eve = career.advance(roundTrip(after.state), { from: after.state.date, to: shift(date, -1) });
  assert.deepEqual(findMail(eve.mail, id), []);
  assert.deepEqual(findMail(eve.mail, id, 'host-guide'), []);
  const skipped = career.advance(eve.state, { from: eve.state.date, to: shift(date, 1) });
  announcement(skipped.mail, id, date, country, 'host-guide');
  assert.deepEqual(findMail(skipped.mail, id), []);

  const exact = career.advance(eve.state, { from: eve.state.date, to: date });
  announcement(exact.mail, id, date, country, 'host-guide');
  const resumed = roundTrip(exact.state);
  assert.doesNotThrow(() => career.validate(resumed));
  assert.deepEqual(editionOn(resumed, id)?.host, early.host);
  const continued = career.advance(resumed, { from: resumed.date, to: shift(resumed.date, 1) });
  assert.deepEqual(findMail(continued.mail, id), []);
  assert.deepEqual(findMail(continued.mail, id, 'host-guide'), []);
});

test('playing the last World Cup match as manager reveals the next edition before advancing the day', () => {
  const previousId = 'rugby-world-cup-2027';
  const id = 'rugby-world-cup-2031';
  const lastDate = competitions.createEdition(previousId).fixtures.find(fixture => fixture.phase === 'final').date;
  const state = career.initial(lastDate, seed);
  const final = editionOn(state, previousId).fixtures.find(fixture => fixture.phase === 'final');
  assert.equal(final.result, null);
  const played = career.play(state, { date: lastDate, fixtureId: final.id, managedNation: final.homeId });
  const host = editionOn(played.state, id)?.host;
  checkHost(host);
  announcement(played.mail, id, lastDate, host.countries[0].name);
  const next = career.advance(played.state, { from: lastDate, to: shift(lastDate, 1), managedNation: final.homeId });
  assert.deepEqual(findMail(next.mail, id), []);
});

test('the 2027 World Cup announcement reaches a club career and survives reopening without duplication', () => {
  const id = 'rugby-world-cup-2027';
  const edition = editionOn(career.initial('2027-01-01', seed), id);
  checkHost(edition?.host);
  assert.equal(edition.host.announcementDate, '2026-10-01');
  assert.deepEqual(edition.host.countries.map(country => country.id), ['AUS']);
  assert.equal(edition.host.city, 'Sydney');
  assert.match(edition.host.stadium, /Stadium Australia|Accor Stadium/);

  const first = bridge(shift(edition.host.announcementDate, -1));
  assert.deepEqual(findMail(first.project().mail, id), []);
  first.advance();
  const published = first.project();
  const received = announcement(published.mail, id, edition.host.announcementDate, edition.host.countries[0].name);
  assert.deepEqual(published.editions.find(candidate => candidate.id === id)?.host, edition.host);

  const saved = roundTrip(first.read());
  const reopened = bridge(saved.career.date, saved);
  assert.deepEqual(reopened.read(), saved);
  reopened.advance();
  assert.deepEqual(findMail(reopened.project().mail, id), [received]);
});

test('the annual and biennial tournament families expose host announcements before their opening matches', () => {
  for (const id of competitions.editionIds(2028, 2030)) {
    const template = competitions.createEdition(id);
    const edition = editionOn(career.initial(template.fixtures[0].date, seed), id);
    checkHost(edition?.host);
    const date = edition.host.announcementDate;
    assert.ok(date < template.fixtures[0].date, id);
    const eve = career.initial(shift(date, -1), seed);
    const opened = career.advance(eve, { from: eve.date, to: date });
    announcement(opened.mail, id, date, edition.host.countries[0].name, 'host-guide');
  }
});

test('the opening Nations Championship distinguishes the finals host from the distributed tournament', () => {
  const edition = editionOn(career.initial('2026-07-01', seed), 'nations-championship-2026');
  checkHost(edition?.host);
  assert.ok(edition.host.countries.length > 1);
  assert.equal(edition.host.finalCountry?.id ?? edition.host.finalCountry, 'ENG');
  assert.match(edition.host.city, /Londres|London|Twickenham/);
  assert.match(edition.host.stadium, /Allianz Stadium|Twickenham/);
});
