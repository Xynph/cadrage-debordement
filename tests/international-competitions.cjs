'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const SIX = 'six-nations-2027';
const CUP = 'rugby-world-cup-2027';
const POOLS = {
  A: ['NZL', 'AUS', 'CHI', 'HKG'], B: ['RSA', 'ITA', 'GEO', 'ROU'],
  C: ['ARG', 'FIJ', 'ESP', 'CAN'], D: ['IRE', 'SCO', 'URU', 'POR'],
  E: ['FRA', 'JPN', 'USA', 'SAM'], F: ['ENG', 'WAL', 'TGA', 'ZIM'],
};
const competition = () => require('../native/engine/international-competitions.cjs');
const score = (home, away, homeTries = 0, awayTries = 0) => ({ home, away, homeTries, awayTries });

test('official opening, French, and final dates are playable across both calendars', () => {
  const { createEdition } = competition();
  const six = createEdition(SIX), cup = createEdition(CUP);
  assert.equal(six.fixtures.length, 15);
  assert.equal(six.fixtures[0].date, '2027-02-05');
  assert.deepEqual(six.fixtures.filter(f => [f.homeId, f.awayId].includes('FRA'))
    .map(f => [f.date, f.homeId, f.awayId]), [
    ['2027-02-06', 'FRA', 'WAL'], ['2027-02-14', 'ENG', 'FRA'],
    ['2027-02-21', 'FRA', 'SCO'], ['2027-03-06', 'ITA', 'FRA'],
    ['2027-03-13', 'IRE', 'FRA'],
  ]);
  assert.equal(new Set(six.fixtures.map(f => [f.homeId, f.awayId].sort().join())).size, 15);
  assert.deepEqual(cup.teams.map(t => t.id).sort(), Object.values(POOLS).flat().sort());
  assert.equal(cup.fixtures.length, 52);
  assert.equal(new Set(cup.fixtures.map(f => f.id)).size, 52);
  assert.deepEqual(cup.fixtures.filter(f => [f.homeId, f.awayId].includes('FRA'))
    .map(f => [f.date, f.homeId, f.awayId]), [
    ['2027-10-02', 'FRA', 'USA'], ['2027-10-09', 'FRA', 'JPN'], ['2027-10-17', 'FRA', 'SAM'],
  ]);
  assert.deepEqual(cup.fixtures.slice(0, 1).map(f => [f.date, f.homeId, f.awayId, f.venue]), [
    ['2027-10-01', 'AUS', 'HKG', 'Perth Stadium'],
  ]);
  for (const [pool, teams] of Object.entries(POOLS)) {
    const matches = cup.fixtures.filter(f => f.pool === pool);
    assert.equal(matches.length, 6);
    assert.equal(new Set(matches.map(f => [f.homeId, f.awayId].sort().join())).size, 6);
    for (const team of teams) assert.equal(matches.filter(f => [f.homeId, f.awayId].includes(team)).length, 3);
  }
  assert.deepEqual(cup.fixtures.slice(-2).map(f => [f.phase, f.date, f.homeId, f.awayId]), [
    ['bronze-final', '2027-11-12', null, null], ['final', '2027-11-13', null, null],
  ]);
});

test('Six Nations uses a four-try bonus, seven-point boundary and five-win Grand Slam', () => {
  const { createEdition, standings, recordResult, editionOutcome } = competition();
  let edition = createEdition(SIX);
  const opening = edition.fixtures[0];
  edition = recordResult(edition, opening.id, score(35, 28, 5, 4));
  let table = standings(edition)[0].rows;
  assert.equal(table.find(row => row.teamId === 'IRE').points, 5);
  assert.deepEqual(table.filter(row => row.teamId === 'ENG').map(row => [row.points, row.tryBonus, row.losingBonus]), [[2, 1, 1]]);
  const scotlandItaly = edition.fixtures[1];
  edition = recordResult(edition, scotlandItaly.id, score(31, 23, 4, 4));
  table = standings(edition)[0].rows;
  assert.equal(table.find(row => row.teamId === 'ITA').points, 1);
  for (const f of edition.fixtures.filter(f => !f.result)) {
    edition = recordResult(edition, f.id, f.homeId === 'IRE' ? score(21, 0, 3) : score(0, 21, 0, 3));
  }
  assert.deepEqual(editionOutcome(edition).winnerIds, ['IRE']);
  assert.deepEqual(editionOutcome(edition).grandSlamIds, ['IRE']);
  assert.deepEqual(editionOutcome(edition).tripleCrownIds, ['IRE']);
  table = standings(edition)[0].rows;
  assert.deepEqual([table[0].teamId, table[0].points, table[0].grandSlamBonus], ['IRE', 24, 3]);
});

test('Six Nations shares rank when points, margin and tries are identical', () => {
  const { createEdition, standings, recordResult, editionOutcome } = competition();
  let edition = createEdition(SIX);
  for (const f of edition.fixtures) edition = recordResult(edition, f.id, score(20, 20, 4, 4));
  const table = standings(edition)[0].rows;
  assert.ok(table.every(row => row.rank === 1 && row.points === 15));
  assert.equal(editionOutcome(edition).winnerIds.length, 6);
});

test('Cup pool ties use head-to-head before points difference', () => {
  const { createEdition, restoreEdition, standings } = competition();
  const cup = createEdition(CUP);
  const results = Object.fromEntries(cup.fixtures.filter(f => f.phase === 'pool').map(f => [f.id, score(0, 0)]));
  const setResult = (first, second, firstScore, secondScore, firstTries, secondTries) => {
    const f = cup.fixtures.find(f => [f.homeId, f.awayId].includes(first) && [f.homeId, f.awayId].includes(second));
    results[f.id] = f.homeId === first ? score(firstScore, secondScore, firstTries, secondTries) : score(secondScore, firstScore, secondTries, firstTries);
  };
  setResult('NZL', 'AUS', 9, 3, 0, 0);
  setResult('CHI', 'NZL', 6, 0, 0, 0);
  setResult('AUS', 'HKG', 24, 0, 0, 0);
  setResult('AUS', 'CHI', 15, 0, 0, 0);
  setResult('NZL', 'HKG', 3, 0, 0, 0);
  // NZL and AUS have 9 match points each. AUS has a much better margin.
  const edition = restoreEdition(CUP, results);
  assert.deepEqual(standings(edition)[0].rows.slice(0, 2).map(row => [row.teamId, row.points]), [['NZL', 9], ['AUS', 9]]);
});

test('Cup third-place comparison uses points scored ahead of tries', () => {
  const { createEdition, restoreEdition, bestThirds } = competition();
  const cup = createEdition(CUP);
  assert.deepEqual(bestThirds(cup), []);
  const results = Object.fromEntries(cup.fixtures.filter(f => f.phase === 'pool').map(f => {
    const pool = POOLS[f.pool];
    const homeRank = pool.indexOf(f.homeId), awayRank = pool.indexOf(f.awayId);
    const thirdVersusFourth = Math.min(homeRank, awayRank) === 2;
    const [forPoints, againstPoints, winnerTries, loserTries] = thirdVersusFourth && f.pool === 'A' ? [18, 6, 0, 0] :
      thirdVersusFourth && f.pool === 'B' ? [17, 5, 1, 1] : [12, 0, 0, 0];
    return [f.id, homeRank < awayRank ? score(forPoints, againstPoints, winnerTries, loserTries) :
      score(againstPoints, forPoints, loserTries, winnerTries)];
  }));
  const ranking = bestThirds(restoreEdition(CUP, results));
  assert.deepEqual(ranking.slice(0, 2).map(row => [row.teamId, row.points, row.pointDifference, row.pointsFor, row.triesFor]), [
    ['CHI', 4, -12, 18, 0],
    ['GEO', 4, -12, 17, 1],
  ]);
});
test('all fifteen official third-place permutations produce exactly sixteen distinct qualifiers', () => {
  const { createEdition, restoreEdition, bestThirds } = competition();
  const cup = createEdition(CUP);
  const opponents = {
    ABCD: ['ESP', 'URU', 'CHI', 'GEO'], ABCE: ['ESP', 'USA', 'CHI', 'GEO'],
    ABCF: ['ESP', 'TGA', 'CHI', 'GEO'], ABDE: ['USA', 'URU', 'CHI', 'GEO'],
    ABDF: ['TGA', 'URU', 'CHI', 'GEO'], ABEF: ['USA', 'TGA', 'CHI', 'GEO'],
    ACDE: ['ESP', 'URU', 'CHI', 'USA'], ACDF: ['ESP', 'URU', 'CHI', 'TGA'],
    ACEF: ['ESP', 'USA', 'CHI', 'TGA'], ADEF: ['USA', 'URU', 'CHI', 'TGA'],
    BCDE: ['ESP', 'URU', 'USA', 'GEO'], BCDF: ['ESP', 'URU', 'TGA', 'GEO'],
    BCEF: ['ESP', 'USA', 'TGA', 'GEO'], BDEF: ['USA', 'URU', 'TGA', 'GEO'],
    CDEF: ['ESP', 'URU', 'USA', 'TGA'],
  };
  for (const [qualifiedPools, awayIds] of Object.entries(opponents)) {
    const results = Object.fromEntries(cup.fixtures.filter(f => f.phase === 'pool').map(f => {
      const pool = POOLS[f.pool];
      const homeRank = pool.indexOf(f.homeId), awayRank = pool.indexOf(f.awayId);
      const bonus = Math.min(homeRank, awayRank) === 2 && qualifiedPools.includes(f.pool);
      const winningScore = bonus ? 28 : 12;
      return [f.id, homeRank < awayRank ? score(winningScore, 0, bonus ? 4 : 0) : score(0, winningScore, 0, bonus ? 4 : 0)];
    }));
    const resolved = restoreEdition(CUP, results);
    const rounds = resolved.fixtures.filter(f => f.phase === 'round-of-16');
    assert.equal(new Set(rounds.flatMap(f => [f.homeId, f.awayId])).size, 16);
    assert.deepEqual(bestThirds(resolved).filter(row => row.qualified).map(row => row.pool).sort().join(''), qualifiedPools);
    assert.deepEqual(rounds.filter(f => ['NZL', 'RSA', 'ARG', 'IRE'].includes(f.homeId)).map(f => f.awayId), awayIds);
    assert.deepEqual(rounds.filter(f => !['NZL', 'RSA', 'ARG', 'IRE'].includes(f.homeId)).map(f => [f.homeId, f.awayId]), [
      ['FIJ', 'WAL'], ['FRA', 'SCO'], ['AUS', 'JPN'], ['ENG', 'ITA'],
    ]);
  }
});

test('knockout propagation, tied kicks and full history survive reverse-order replay', () => {
  const { createEdition, restoreEdition, simulateResult, recordResult, editionOutcome } = competition();
  const cup = createEdition(CUP);
  const firstKnockout = cup.fixtures.find(f => f.phase === 'round-of-16');
  assert.throws(() => recordResult(cup, firstKnockout.id, score(12, 0)), /unresolved/i);
  let edition = cup;
  for (const { id } of cup.fixtures) {
    const fixture = edition.fixtures.find(f => f.id === id);
    const result = fixture.phase === 'final' ?
      { ...score(0, 0), winnerId: fixture.awayId, decidedBy: 'kicking-competition' } :
      simulateResult(edition, id, { seed: 'career-2411' });
    if (fixture.phase === 'final') assert.throws(() => recordResult(edition, id, score(0, 0)), /winner/i);
    edition = recordResult(edition, id, result);
    assert.deepEqual(recordResult(edition, id, result), edition);
  }
  const match = phase => edition.fixtures.find(f => f.phase === phase);
  const outcome = editionOutcome(edition);
  assert.equal(outcome.complete, true);
  assert.deepEqual(outcome.winnerIds, [match('final').awayId]);
  assert.deepEqual(outcome.runnerUpIds, [match('final').homeId]);
  assert.deepEqual(outcome.thirdPlaceIds, [match('bronze-final').result.winnerId]);
  assert.equal(new Set([...outcome.winnerIds, ...outcome.runnerUpIds, ...outcome.thirdPlaceIds]).size, 3);
  assert.equal(cup.fixtures.every(f => f.result === null), true);
  const results = Object.fromEntries(edition.fixtures.slice().reverse().map(f => [f.id, f.result]));
  assert.deepEqual(restoreEdition(CUP, JSON.parse(JSON.stringify(results))), edition);
  assert.throws(() => restoreEdition(CUP, { fabricated: score(12, 0) }), /unknown fixture/i);
  assert.throws(() => recordResult(edition, edition.fixtures[0].id, score(0, 0)), /already recorded/i);
  assert.throws(() => recordResult(cup, cup.fixtures[0].id, score(3, 0, 1)), /score/i);
});

test('simulation uses repeatable match seeds and supplies legally scorable totals', () => {
  const { createEdition, simulateResult, recordResult } = competition();
  const edition = createEdition(SIX), fixture = edition.fixtures[0];
  const options = { seed: 'career-2411', homeStrength: 92, awayStrength: 69 };
  assert.deepEqual(simulateResult(edition, fixture.id, options), simulateResult(edition, fixture.id, options));
  let homeWins = 0;
  for (let seed = 0; seed < 100; seed++) {
    const result = simulateResult(edition, fixture.id, { ...options, seed });
    assert.doesNotThrow(() => recordResult(edition, fixture.id, result));
    if (result.winnerId === fixture.homeId) homeWins++;
  }
  assert.ok(homeWins > 75 && homeWins < 100, 'ratings affect probabilities without guaranteeing every result');
});
