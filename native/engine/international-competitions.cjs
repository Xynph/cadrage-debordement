'use strict';

const {
  SIX_NATIONS, WORLD_CUP, sources, teamNames,
  sixNationsTeams, sixNationsVenues, sixNationsSchedule,
  worldCupPools, worldCupVenues, worldCupPoolSchedule, worldCupKnockoutSchedule,
  thirdPlacePermutations, defaultRankings,
} = require('./international-2027.cjs');
const nations = require('./nations-championship-2026.cjs');
const rugbyChampionship = require('./rugby-championship-2027.cjs');
const {
  editionIds, editionYear, templateId, sixNationsCalendar, nationsCalendar, rugbyChampionshipCalendar,
  hostCountryId, worldCupGroups, worldCupCalendar, simulatedProvenance,
} = require('./international-edition-calendar.cjs');

const COMPETITION_IDS = Object.freeze([SIX_NATIONS, WORLD_CUP, nations.id, rugbyChampionship.id]);
const homeUnions = ['ENG', 'IRE', 'SCO', 'WAL'];
const phasesWithTables = new Set(['league', 'pool']);
const editionsWithSharedRanks = new Set([SIX_NATIONS, rugbyChampionship.id]);
const beforeKickoff = (a, b) => a.date.localeCompare(b.date);
const assert = (condition, message) => { if (!condition) throw new Error(message); };

function editionGroups(competitionId) {
  const template = templateId(competitionId);
  if (template === WORLD_CUP) {
    if (competitionId === WORLD_CUP) return Object.entries(worldCupPools);
    const year = editionYear(competitionId);
    return worldCupGroups(year, fixtureRandom(year, 'world-cup-draw'));
  }
  if (template === nations.id) return Object.entries(nations.hemispheres);
  return [[null, template === rugbyChampionship.id ? rugbyChampionship.teams : sixNationsTeams]];
}

function createEdition(competitionId, { rankings = defaultRankings, drawSeed = 0 } = {}) {
  const year = editionYear(competitionId);
  assert(year !== null, 'unknown international competition: ' + competitionId);
  const template = templateId(competitionId);
  const recurring = competitionId !== template;
  const sixNations = template === SIX_NATIONS;
  const nationsChampionship = template === nations.id;
  const trc = template === rugbyChampionship.id;
  const groups = editionGroups(competitionId);
  const teamIds = groups.flatMap(([, ids]) => ids);
  assert(Array.isArray(rankings) && new Set(rankings).size === rankings.length &&
    rankings.every(id => Object.hasOwn(teamNames, id)) &&
    teamIds.every(id => rankings.includes(id)), 'rankings must list every participating team once');
  const fixture = (key, day, kickoffLocal, round, phase, pool, homeId, awayId, venue, neutralVenue = false) => ({
    id: competitionId + '-' + key,
    competitionId,
    date: year + '-' + day,
    kickoffLocal,
    round,
    phase,
    pool,
    homeId,
    awayId,
    neutralVenue,
    venue,
    result: null,
    ...(recurring ? { dateStatus: 'simulated' } : {}),
  });

  let fixtures;
  if (sixNations) {
    const schedule = recurring ? sixNationsCalendar(year) : sixNationsSchedule;
    fixtures = schedule.flatMap((matches, r) => matches.map(([day, kickoff, home, away], i) =>
      fixture('r' + (r + 1) + '-' + (i + 1), day, kickoff, r + 1, 'league', null, home, away,
        recurring ? null : sixNationsVenues[home])));
  } else if (nationsChampionship) {
    assert(typeof drawSeed === 'string' || Number.isFinite(drawSeed), 'invalid Nations Championship draw seed');
    const { leagueSchedule, finalsSchedule } = recurring ? nationsCalendar(year) : nations;
    fixtures = leagueSchedule.flatMap((matches, r) => matches.map(([day, kickoff, home, away, venue, neutral], i) =>
      fixture('r' + (r + 1) + '-' + (i + 1), day, kickoff, r + 1, 'league', null, home, away, venue, neutral)));
    for (const [day, kickoff, placement] of finalsSchedule) {
      const phase = placement === 1 ? 'final' : 'placement';
      const key = placement === 1 ? 'final' : 'placement-' + placement;
      fixtures.push({
        ...fixture(key, day, kickoff, 7, phase, null, null, null, recurring ? null : 'Allianz Stadium', true),
        placement,
        homeSource: 'north-' + placement,
        awaySource: 'south-' + placement,
      });
    }
  } else if (trc) {
    const schedule = recurring ? rugbyChampionshipCalendar(year) : rugbyChampionship.schedule;
    fixtures = schedule.flatMap(([day, matches], r) => matches.map(([home, away, venue], i) => ({
      ...fixture('r' + (r + 1) + '-' + (i + 1), day, null, r + 1, 'league', null, home, away, venue ?? null),
      dateStatus: venue ? 'official' : 'simulated',
    })));
  } else {
    const { poolSchedule, knockoutSchedule } = recurring ? worldCupCalendar(year, groups) : {
      poolSchedule: Object.entries(worldCupPoolSchedule), knockoutSchedule: worldCupKnockoutSchedule,
    };
    fixtures = poolSchedule.flatMap(([pool, matches]) => matches.map(([day, kickoff, venue, home, away], i) =>
      fixture('pool-' + pool.toLowerCase() + '-' + (i + 1), recurring ? day : '10-' + String(day).padStart(2, '0'),
        kickoff, Math.floor(i / 2) + 1, 'pool', pool, home, away, worldCupVenues[venue] ?? null, true))).sort(beforeKickoff);
    for (const [key, day, kickoff, venue, round, phase, homeSource, awaySource] of knockoutSchedule) {
      fixtures.push({
        ...fixture(key, day, kickoff, round, phase, null, null, null, worldCupVenues[venue] ?? null, true),
        homeSource,
        awaySource,
      });
    }
  }

  return {
    id: competitionId,
    name: (sixNations ? 'Tournoi des Six Nations' :
      nationsChampionship ? 'Nations Championship' : trc ? 'Rugby Championship' : 'Coupe du monde de rugby') + ' ' + year,
    year,
    ...(nationsChampionship ? { drawSeed } : {}),
    ...(recurring && template === WORLD_CUP ? { hostCountryId: hostCountryId(year) } : {}),
    teams: teamIds.map(id => ({ id, name: teamNames[id] })),
    rankings: rankings.filter(id => teamIds.includes(id)),
    fixtures,
    provenance: recurring ? simulatedProvenance(template, year) : sixNations ? {
      calendar: sources.sixNationsCalendar,
      rules: sources.sixNationsRules,
    } : nationsChampionship ? { ...nations.provenance } : trc ? { ...rugbyChampionship.provenance } : {
      calendar: sources.worldCupCalendar,
      draw: sources.worldCupDraw,
      bestThirds: sources.worldCupThirds,
      provisionalRules: sources.worldCupPreviousRules,
      rankingFallback: 'in-game-order',
    },
  };
}

function fixturesForTable(edition, pool, crossHemisphere) {
  return edition.fixtures.filter(f => phasesWithTables.has(f.phase) && (crossHemisphere || f.pool === pool));
}

function newRow(teamId) {
  return {
    teamId, rank: 0, played: 0, won: 0, drawn: 0, lost: 0, points: 0,
    pointsFor: 0, pointsAgainst: 0, pointDifference: 0, triesFor: 0, triesAgainst: 0,
    tryBonus: 0, losingBonus: 0, grandSlamBonus: 0,
  };
}

function addMatch(row, scored, conceded, tries, concededTries, useTryMargin) {
  row.played++;
  row.pointsFor += scored;
  row.pointsAgainst += conceded;
  row.pointDifference += scored - conceded;
  row.triesFor += tries;
  row.triesAgainst += concededTries;
  const tryBonus = Number(useTryMargin ? tries - concededTries >= 3 : tries >= 4);
  const losingBonus = Number(scored < conceded && conceded - scored <= 7);
  row.tryBonus += tryBonus;
  row.losingBonus += losingBonus;
  row.points += tryBonus + losingBonus;
  if (scored > conceded) {
    row.won++;
    row.points += 4;
  } else if (scored === conceded) {
    row.drawn++;
    row.points += 2;
  } else {
    row.lost++;
  }
}

function sixNationsOrder(a, b) {
  return b.points - a.points || b.pointDifference - a.pointDifference || b.triesFor - a.triesFor;
}

function poolOrder(rows, fixtures, rankings) {
  const criteria = [
    row => row.pointDifference,
    row => row.triesFor - row.triesAgainst,
    row => row.pointsFor,
    row => row.triesFor,
    row => -rankings.indexOf(row.teamId),
  ];
  const remaining = [...rows];
  const ordered = [];
  while (remaining.length) {
    const bestPoints = Math.max(...remaining.map(row => row.points));
    let tied = remaining.filter(row => row.points === bestPoints);
    if (tied.length === 2) {
      const teams = tied.map(row => row.teamId);
      const headToHead = fixtures.find(f => teams.includes(f.homeId) && teams.includes(f.awayId));
      if (headToHead?.result?.winnerId) tied = tied.filter(row => row.teamId === headToHead.result.winnerId);
    }
    for (const metric of criteria) {
      if (tied.length === 1) break;
      const best = Math.max(...tied.map(metric));
      tied = tied.filter(row => metric(row) === best);
    }
    const [best] = tied;
    ordered.push(best);
    remaining.splice(remaining.indexOf(best), 1);
  }
  return ordered;
}

function nationsOrder(rows, pool, drawSeed) {
  const lots = rows.map(row => row.teamId);
  const random = fixtureRandom(drawSeed, 'hemisphere-' + pool);
  for (let i = lots.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [lots[i], lots[j]] = [lots[j], lots[i]];
  }
  return rows.sort((a, b) => b.points - a.points || b.won - a.won ||
    b.pointDifference - a.pointDifference || (b.triesFor - b.triesAgainst) - (a.triesFor - a.triesAgainst) ||
    b.triesFor - a.triesFor || lots.indexOf(a.teamId) - lots.indexOf(b.teamId));
}

function rugbyChampionshipOrder(rows, fixtures) {
  const direct = new Map(rows.map(row => [row.teamId, { won: 0, margin: 0, points: row.points }]));
  for (const { homeId, awayId, result } of fixtures) {
    if (!result) continue;
    const home = direct.get(homeId), away = direct.get(awayId);
    if (home.points !== away.points) continue;
    home.won += Number(result.winnerId === homeId);
    away.won += Number(result.winnerId === awayId);
    home.margin += result.home - result.away;
    away.margin += result.away - result.home;
  }
  return (a, b) => {
    const aDirect = direct.get(a.teamId), bDirect = direct.get(b.teamId);
    return b.points - a.points || b.won - a.won || bDirect.won - aDirect.won ||
      b.pointDifference - a.pointDifference || bDirect.margin - aDirect.margin || b.triesFor - a.triesFor;
  };
}

function standings(edition) {
  const template = templateId(edition.id);
  const sixNations = template === SIX_NATIONS;
  const trc = template === rugbyChampionship.id;
  const crossHemisphere = template === nations.id;
  return editionGroups(edition.id).map(([pool, teamIds]) => {
    const fixtures = fixturesForTable(edition, pool, crossHemisphere);
    const rows = new Map(teamIds.map(id => [id, newRow(id)]));
    for (const { homeId, awayId, result } of fixtures) {
      if (!result) continue;
      if (rows.has(homeId)) addMatch(rows.get(homeId), result.home, result.away, result.homeTries, result.awayTries, trc);
      if (rows.has(awayId)) addMatch(rows.get(awayId), result.away, result.home, result.awayTries, result.homeTries, trc);
    }
    if (sixNations) {
      for (const row of rows.values()) {
        if (row.won !== 5) continue;
        row.grandSlamBonus = 3;
        row.points += row.grandSlamBonus;
      }
    }
    const entries = [...rows.values()];
    const leagueOrder = trc ? rugbyChampionshipOrder(entries, fixtures) : sixNations ? sixNationsOrder : null;
    const ordered = leagueOrder ? entries.sort(leagueOrder) : crossHemisphere ?
      nationsOrder(entries, pool, edition.drawSeed) : poolOrder(entries, fixtures, edition.rankings);
    ordered.forEach((row, i) => {
      const previous = ordered[i - 1];
      row.rank = leagueOrder && previous && leagueOrder(previous, row) === 0 ? previous.rank : i + 1;
    });
    return { pool, rows: ordered };
  });
}

function poolStageComplete(edition) {
  return edition.fixtures.filter(f => f.phase === 'pool').every(f => f.result);
}

function rankedThirds(tables, rankings) {
  return tables.map(({ pool, rows }) => ({ ...rows[2], pool }))
    .sort((a, b) => b.points - a.points || b.pointDifference - a.pointDifference ||
      b.pointsFor - a.pointsFor || b.triesFor - a.triesFor ||
      rankings.indexOf(a.teamId) - rankings.indexOf(b.teamId))
    .map((row, i) => ({ ...row, rank: i + 1, qualified: i < 4 }));
}

function bestThirds(edition) {
  if (templateId(edition.id) !== WORLD_CUP || !poolStageComplete(edition)) return [];
  return rankedThirds(standings(edition), edition.rankings);
}

function losingTeam(fixture) {
  return fixture.result.winnerId === fixture.homeId ? fixture.awayId : fixture.homeId;
}

function resolveWorldCupBracket(edition) {
  if (!poolStageComplete(edition)) return edition;
  const firstKnockout = edition.fixtures.find(f => f.phase === 'round-of-16');
  const seeds = new Map();
  if (!firstKnockout.homeId) {
    const tables = standings(edition);
    const qualifiedPools = rankedThirds(tables, edition.rankings).filter(row => row.qualified).map(row => row.pool).sort().join('');
    for (const { pool, rows } of tables) {
      for (const row of rows) seeds.set(pool + row.rank, row.teamId);
    }
    const permutation = thirdPlacePermutations[qualifiedPools];
    [...'ABCD'].forEach((pool, i) => seeds.set('T' + pool, seeds.get(permutation[i] + '3')));
  }
  const fixtures = new Map();
  const resolveSource = source => {
    if (seeds.has(source)) return seeds.get(source);
    const previous = fixtures.get(edition.id + '-' + source.slice(1));
    if (!previous?.result) return null;
    return source.startsWith('W') ? previous.result.winnerId : losingTeam(previous);
  };

  return {
    ...edition,
    fixtures: edition.fixtures.map(f => {
      const homeId = f.homeId ?? (f.homeSource ? resolveSource(f.homeSource) : null);
      const awayId = f.awayId ?? (f.awaySource ? resolveSource(f.awaySource) : null);
      const resolved = homeId === f.homeId && awayId === f.awayId ? f : { ...f, homeId, awayId };
      fixtures.set(resolved.id, resolved);
      return resolved;
    }),
  };
}

function resolveNationsFinals(edition) {
  const final = edition.fixtures.find(f => f.phase === 'final');
  if (final.homeId || edition.fixtures.some(f => f.phase === 'league' && !f.result)) return edition;
  const [north, south] = standings(edition);
  return {
    ...edition,
    fixtures: edition.fixtures.map(f => f.placement ? {
      ...f,
      homeId: north.rows[f.placement - 1].teamId,
      awayId: south.rows[f.placement - 1].teamId,
    } : f),
  };
}

function validRugbyScore(points, tries) {
  if (!Number.isSafeInteger(points) || points < 0 || !Number.isSafeInteger(tries) || tries < 0) return false;
  const unconverted = points - 5 * tries;
  if (unconverted < 0) return false;
  // Conversions and penalty tries add two; penalty goals and drops add three.
  const minConversions = (unconverted % 3) * 2 % 3;
  return minConversions <= tries && 2 * minConversions <= unconverted;
}

function canonicalResult(fixture, result) {
  assert(result && typeof result === 'object' &&
    validRugbyScore(result.home, result.homeTries) &&
    validRugbyScore(result.away, result.awayTries), 'invalid rugby score or try count');
  const { home, away, homeTries, awayTries, decidedBy } = result;
  const tied = home === away;
  const knockout = !phasesWithTables.has(fixture.phase);
  let winnerId = tied ? null : (home > away ? fixture.homeId : fixture.awayId);
  const mustDecide = knockout && fixture.phase !== 'placement';
  if (tied && mustDecide) {
    assert([fixture.homeId, fixture.awayId].includes(result.winnerId), 'knockout draw requires a winner from kicks');
    winnerId = result.winnerId;
  }
  assert(result.winnerId === undefined || result.winnerId === winnerId, 'winner conflicts with score');
  const normalExtraTime = templateId(fixture.competitionId) === WORLD_CUP && decidedBy === 'extra-time';
  assert(decidedBy === undefined || (knockout && (tied ? mustDecide && decidedBy === 'kicking-competition' :
    normalExtraTime || decidedBy === 'sudden-death')), 'invalid knockout deciding method');
  const canonical = { home, away, homeTries, awayTries, winnerId };
  if (decidedBy) canonical.decidedBy = decidedBy;
  else if (tied && mustDecide) canonical.decidedBy = 'kicking-competition';
  return canonical;
}

function readyFixture(edition, fixtureId) {
  const fixture = edition.fixtures.find(f => f.id === fixtureId);
  assert(fixture, 'unknown fixture: ' + fixtureId);
  assert(fixture.homeId && fixture.awayId, 'fixture participants unresolved: ' + fixtureId);
  return fixture;
}

function recordResult(edition, fixtureId, result) {
  const fixture = readyFixture(edition, fixtureId);
  const score = canonicalResult(fixture, result);
  if (fixture.result) {
    assert(Object.keys(score).length === Object.keys(fixture.result).length &&
      Object.entries(score).every(([key, value]) => fixture.result[key] === value), 'fixture result already recorded: ' + fixtureId);
    return edition;
  }
  const updated = { ...edition, fixtures: edition.fixtures.map(f => f === fixture ? { ...f, result: score } : f) };
  const template = templateId(edition.id);
  if (template === WORLD_CUP) return resolveWorldCupBracket(updated);
  if (template === nations.id) return resolveNationsFinals(updated);
  return updated;
}

function restoreEdition(competitionId, results = {}, options = {}) {
  let edition = createEdition(competitionId, options);
  assert(results && [null, Object.prototype].includes(Object.getPrototypeOf(results)), 'fixture result map required');
  const allowedIds = new Set(edition.fixtures.map(f => f.id));
  for (const id of Object.keys(results)) assert(allowedIds.has(id), 'unknown fixture: ' + id);
  for (const { id } of edition.fixtures) {
    if (Object.hasOwn(results, id)) edition = recordResult(edition, id, results[id]);
  }
  return edition;
}

function editionOutcome(edition) {
  const outcome = {
    complete: edition.fixtures.every(f => f.result),
    winnerIds: [], runnerUpIds: [], thirdPlaceIds: [],
    grandSlamIds: [], tripleCrownIds: [],
  };
  const template = templateId(edition.id);
  if (editionsWithSharedRanks.has(template)) {
    const [{ rows }] = standings(edition);
    if (template === SIX_NATIONS) {
      outcome.grandSlamIds = rows.filter(row => row.grandSlamBonus).map(row => row.teamId);
      outcome.tripleCrownIds = homeUnions.filter(id => edition.fixtures.filter(f =>
        f.result?.winnerId === id && homeUnions.includes(f.homeId) && homeUnions.includes(f.awayId)).length === 3);
    }
    if (outcome.complete) {
      outcome.winnerIds = rows.filter(row => row.rank === 1).map(row => row.teamId);
      outcome.runnerUpIds = rows.filter(row => row.rank === 2).map(row => row.teamId);
      outcome.thirdPlaceIds = rows.filter(row => row.rank === 3).map(row => row.teamId);
    }
  } else {
    const final = edition.fixtures.find(f => f.phase === 'final');
    const bronze = edition.fixtures.find(f => f.phase === 'bronze-final' || f.placement === 2);
    if (final.result) {
      outcome.winnerIds = [final.result.winnerId];
      outcome.runnerUpIds = [losingTeam(final)];
    }
    if (bronze.result) outcome.thirdPlaceIds = bronze.result.winnerId ? [bronze.result.winnerId] : [bronze.homeId, bronze.awayId];
    if (template === nations.id) {
      const points = { north: 0, south: 0 };
      for (const f of edition.fixtures.filter(f => f.placement && f.result)) {
        const value = f.placement === 1 ? 2 : 1;
        if (!f.result.winnerId) {
          points.north += value / 2;
          points.south += value / 2;
        } else {
          const hemisphere = f.result.winnerId === f.homeId ? 'north' : 'south';
          points[hemisphere] += value;
        }
      }
      outcome.hemispherePoints = points;
      outcome.hemisphereWinner = Object.keys(points).find(hemisphere => points[hemisphere] >= 4) ?? null;
    }
  }
  return outcome;
}

function fixtureRandom(seed, fixtureId) {
  let state = 2166136261;
  for (const character of String(seed) + ':' + fixtureId) {
    state = Math.imul(state ^ character.codePointAt(0), 16777619);
  }
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let mixed = Math.imul(state ^ (state >>> 15), state | 1);
    mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61);
    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296;
  };
}

function poisson(rate, random) {
  let attempts = 0, product = 1;
  const limit = Math.exp(-rate);
  do {
    attempts++;
    product *= random();
  } while (product > limit);
  return attempts - 1;
}

function scorePeriod(difference, duration, random) {
  const tries = poisson(2.7 * Math.exp(difference / 38) * duration, random);
  let points = 5 * tries + 3 * poisson(2.5 * duration, random);
  for (let i = 0; i < tries; i++) if (random() < 0.74) points += 2;
  return { points, tries };
}

function simulateResult(edition, fixtureId, { seed = 0, homeStrength, awayStrength } = {}) {
  const fixture = readyFixture(edition, fixtureId);
  const defaultStrength = teamId => 91 - 2.05 * defaultRankings.indexOf(teamId);
  const rating = (value, teamId) => Number.isFinite(value) ? Math.max(30, Math.min(100, value)) : defaultStrength(teamId);
  const homeAdvantage = fixture.neutralVenue ? 0 : 3;
  const template = templateId(edition.id);
  const host = template === WORLD_CUP ? hostCountryId(edition.year) : null;
  const hostAdvantage = host ? 3 * (Number(fixture.homeId === host) - Number(fixture.awayId === host)) : 0;
  const difference = rating(homeStrength, fixture.homeId) - rating(awayStrength, fixture.awayId) + homeAdvantage + hostAdvantage;
  const random = fixtureRandom(seed, fixture.id);
  const result = { home: 0, away: 0, homeTries: 0, awayTries: 0 };
  function playPeriod(duration) {
    const home = scorePeriod(difference, duration, random);
    const away = scorePeriod(-difference, duration, random);
    result.home += home.points;
    result.away += away.points;
    result.homeTries += home.tries;
    result.awayTries += away.tries;
  }
  playPeriod(1);

  if (!phasesWithTables.has(fixture.phase) && result.home === result.away) {
    if (template === WORLD_CUP) {
      playPeriod(0.25);
      if (result.home !== result.away) {
        result.decidedBy = 'extra-time';
        return canonicalResult(fixture, result);
      }
    }
    const goldenPeriods = template === nations.id && fixture.phase === 'final' ? 2 : 1;
    let favouredHome = false;
    for (let period = 0; period < goldenPeriods; period++) {
      const home = scorePeriod(difference, 0.125, random);
      const away = scorePeriod(-difference, 0.125, random);
      favouredHome = random() < 1 / (1 + Math.exp(-difference / 23));
      if (!home.points && !away.points) continue;
      const homeScores = home.points && (!away.points || favouredHome);
      const firstScore = (homeScores ? home : away).tries ? 5 : 3;
      result[homeScores ? 'home' : 'away'] += firstScore;
      if (firstScore === 5) result[homeScores ? 'homeTries' : 'awayTries']++;
      result.decidedBy = 'sudden-death';
      return canonicalResult(fixture, result);
    }
    if (fixture.phase !== 'placement') {
      result.winnerId = favouredHome ? fixture.homeId : fixture.awayId;
      result.decidedBy = 'kicking-competition';
    }
  }
  return canonicalResult(fixture, result);
}

module.exports = {
  COMPETITION_IDS, editionIds, createEdition, restoreEdition, standings, bestThirds, editionOutcome, recordResult, simulateResult,
};
