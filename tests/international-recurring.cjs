'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  COMPETITION_IDS, editionIds, createEdition, restoreEdition, standings,
  bestThirds, editionOutcome, recordResult, simulateResult,
} = require('../native/engine/international-competitions.cjs');
const { releasePeriods } = require('../native/engine/international-callups.cjs');

test('recurring editions respect the transition calendar and keep the four initial IDs', () => {
  assert.deepEqual(new Set(editionIds(2026, 2027)), new Set(COMPETITION_IDS));
  assert.deepEqual(editionIds(2028, 2031), [
    'six-nations-2028', 'nations-championship-2028', 'rugby-championship-2028',
    'six-nations-2029', 'rugby-championship-2029',
    'six-nations-2030', 'nations-championship-2030',
    'six-nations-2031', 'rugby-championship-2031', 'rugby-world-cup-2031',
  ]);
  assert.deepEqual(editionIds(2025, 2025), []);
  assert.deepEqual(editionIds(2031, 2030), []);
  assert.throws(() => editionIds(2028.5, 2030), /year/i);
  for (const id of ['rugby-championship-2026', 'rugby-championship-2030',
    'nations-championship-2029', 'rugby-world-cup-2032', 'six-nations-02028']) {
    assert.throws(() => createEdition(id), /unknown international competition/i);
  }
});

test('future tours balance hosts and recurring tournaments use separate release periods', () => {
  const opponents = edition => Object.fromEntries(edition.fixtures.map(f => [[f.homeId, f.awayId].sort().join('/'), f.homeId]));
  const a = opponents(createEdition('six-nations-2027')), b = opponents(createEdition('six-nations-2028'));
  assert.deepEqual(Object.keys(a).sort(), Object.keys(b).sort());
  assert.ok(Object.keys(a).every(pair => a[pair] !== b[pair]));
  const nations = createEdition('nations-championship-2028');
  const league = nations.fixtures.filter(f => f.phase === 'league');
  assert.equal(new Set(league.map(f => [f.homeId, f.awayId].sort().join('/'))).size, 36);
  for (const { id } of nations.teams) {
    const matches = league.filter(f => f.homeId === id || f.awayId === id);
    assert.equal(matches.filter(f => f.homeId === id).length, 3);
    assert.equal(new Set(matches.map(f => f.date)).size, 6);
  }

  for (let year = 2028; year <= 2060; year++) {
    const editions = editionIds(year, year).map(id => createEdition(id));
    const trc = editions.find(e => e.id.startsWith('rugby-championship'));
    if (trc) for (const { id } of trc.teams) {
      const matches = trc.fixtures.filter(f => f.homeId === id || f.awayId === id);
      assert.equal(matches.length, 6);
      assert.equal(matches.filter(f => f.homeId === id).length, 3);
      assert.equal(new Set(matches.map(f => f.homeId === id ? f.awayId : f.homeId)).size, 3);
    }
    const periods = editions.flatMap(e => releasePeriods(e.fixtures, {
      worldCup: e.id.startsWith('rugby-world-cup-'), openingDate: e.fixtures[0].date,
    }).map(period => ({ id: e.id, ...period })));
    for (const a of periods) for (const b of periods) {
      if (a.id !== b.id) assert.ok(a.through < b.from || b.through < a.from, a.id + ' overlaps ' + b.id);
    }
  }
});

test('simulated future editions play and restore through their respective title rules', () => {
  for (const id of editionIds(2028, 2031)) {
    const original = createEdition(id);
    const phases = new Set(original.fixtures.map(f => f.phase));
    assert.deepEqual(createEdition(id), original);
    assert.ok(original.fixtures.every(f => f.date.startsWith(String(original.year)) &&
      f.dateStatus === 'simulated'));
    let edition = original;
    for (const f of original.fixtures) {
      edition = recordResult(edition, f.id, simulateResult(edition, f.id, { seed: 'long-career' }));
    }
    const result = editionOutcome(edition);
    assert.equal(result.complete, true);
    assert.ok(result.winnerIds.length);
    if (phases.has('pool')) {
      assert.equal(original.hostCountryId, 'USA');
      assert.equal(original.fixtures[0].homeId, 'USA');
      assert.equal(original.fixtures.length, 52);
      assert.ok(original.fixtures.every(f => f.venue === null && f.neutralVenue));
      assert.equal(standings(edition).length, 6);
      assert.ok(standings(edition).every(t => t.rows.length === 4 && t.rows.every(r => r.played === 3)));
      assert.equal(bestThirds(edition).filter(row => row.qualified).length, 4);
      assert.equal(new Set(edition.fixtures.filter(f => f.phase === 'round-of-16')
        .flatMap(f => [f.homeId, f.awayId])).size, 16);
      assert.equal(result.thirdPlaceIds.length, 1);
    }
    if (phases.has('placement')) assert.ok(result.hemisphereWinner);
    assert.deepEqual(restoreEdition(id, Object.fromEntries(edition.fixtures.slice().reverse()
      .map(f => [f.id, f.result]))), edition);
  }
});
