'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createEdition, restoreEdition, editionIds, recordResult, simulateResult } =
  require('../native/engine/international-competitions.cjs');

const dossier = edition => require('../native/engine/international-hosts.cjs').hostDossier(edition);
const host = id => dossier(createEdition(id));

test('the 2027 World Cup dossier reflects the official country, cities and final', () => {
  const report = host('rugby-world-cup-2027');
  assert.deepEqual([report.finalCountry, report.city, report.stadium], ['AUS', 'Sydney', 'Stadium Australia']);
  assert.deepEqual([report.opens, report.ends, report.announcementDate], ['2027-10-01', '2027-11-13', '2026-10-01']);
  assert.equal(report.officialHostAnnouncementDate, '2022-05-12');
  assert.deepEqual(report.countries.map(({ id, name, capital, matchCount }) => [id, name, capital, matchCount]),
    [['AUS', 'Australie', 'Canberra', 52]]);
  assert.equal(report.countries[0].cities.length, 7);
  assert.equal(report.countries[0].stadiums.length, 8);
});

test('2031 preserves confirmed USA and leaves its final venue open', () => {
  const edition = createEdition('rugby-world-cup-2031');
  const report = dossier(edition);
  assert.deepEqual([report.finalCountry, report.city, report.stadium], ['USA', null, null]);
  assert.equal(report.hostStatus, 'confirmed');
  assert.equal(report.venueStatus, 'pending');
  assert.equal(report.announcementDate, '2028' + report.opens.slice(4));
  assert.equal(report.countries[0].capital, 'Washington, D.C.');
  assert.ok(edition.fixtures.every(f => f.venue === null));
});

test('the Nations Championship separates physical home venues from designated home teams', () => {
  const report = host('nations-championship-2026');
  assert.deepEqual([report.finalCountry, report.city, report.stadium], ['ENG', 'Londres', 'Allianz Stadium']);
  assert.deepEqual([report.opens, report.ends, report.announcementDate], ['2026-07-04', '2026-11-29', '2026-03-04']);
  assert.ok(!report.countries.some(c => c.id === 'FIJ'));
  assert.equal(report.countries.find(c => c.id === 'AUS').matchCount, 4);
  assert.equal(report.countries.reduce((sum, c) => sum + c.matchCount, 0), 42);
});

test('league tournaments list the home unions and keep their decisive day separate from a final', () => {
  const six = host('six-nations-2027'), trc = host('rugby-championship-2027');
  assert.deepEqual(six.countries.map(c => c.id), ['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL']);
  assert.deepEqual(trc.countries.map(c => c.id), ['ARG', 'AUS', 'NZL', 'RSA']);
  assert.equal(six.finalCountry, null);
  assert.equal(six.city, null);
  assert.equal(trc.finalDate, null);
  assert.equal(six.announcementDate, '2026-10-05');
  assert.equal(trc.announcementDate, '2027-03-10');
});

test('future hosts are stable, the stadium agrees with fixtures, and results do not alter the dossier', () => {
  const cups = editionIds(2035, 2080).filter(id => id.startsWith('rugby-world-cup-'));
  assert.ok(new Set(cups.map(id => host(id).finalCountry)).size >= 4);
  assert.equal(host(cups[0]).finalCountry, 'ESP');
  assert.equal(host('nations-championship-2028').finalCountry, 'FRA');
  assert.equal(host('nations-championship-2030').finalCountry, 'USA');
  for (const id of [...cups, 'nations-championship-2028', 'nations-championship-2030', 'nations-championship-2032']) {
    const edition = createEdition(id);
    const report = dossier(edition);
    assert.equal(report.hostStatus, 'simulated');
    const final = edition.fixtures.find(f => f.phase === 'final');
    assert.equal(final.venue, report.stadium);
    assert.equal(report.countries[0].id, report.finalCountry);
    assert.ok(report.countries.every(c => c.name && c.capital && c.details.length));
    if (id.startsWith('rugby-world-cup-')) {
      assert.equal(edition.hostCountryId, report.finalCountry);
      assert.ok(edition.teams.some(t => t.id === report.finalCountry));
    }
    const result = simulateResult(edition, edition.fixtures[0].id, { seed: 8 });
    const played = recordResult(edition, edition.fixtures[0].id, result);
    assert.deepEqual(dossier(played), report);
    assert.deepEqual(dossier(restoreEdition(id, { [edition.fixtures[0].id]: result })), report);
  }
});
