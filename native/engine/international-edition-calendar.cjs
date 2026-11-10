'use strict';

const { SIX_NATIONS, WORLD_CUP, sixNationsSchedule, worldCupKnockoutSchedule, defaultRankings } = require('./international-2027.cjs');
const nations = require('./nations-championship-2026.cjs');
const trc = require('./rugby-championship-2027.cjs');

const definitions = [
  [SIX_NATIONS, year => year >= 2027],
  [nations.id, year => year >= 2026 && year % 2 === 0],
  [trc.id, year => year >= 2027 && year !== 2030],
  [WORLD_CUP, isWorldCupYear],
];
const definitionsByPrefix = new Map(definitions.map(def => [def[0].slice(0, -4), def]));
const regulation9 = 'https://www.world.rugby/organisation/governance/regulations/reg-9';
const sanzaar = trc.provenance.calendar;
const cupHosts = 'https://www.world.rugby/news/714742/rugby-world-cup-host-locations-confirmed-through-to-2033';
const cup2031Selection = 'https://www.world.rugby/media-zone/advisory/1018093';
const dayMs = 86400000;

function isWorldCupYear(year) {
  return year >= 2027 && (year - 2027) % 4 === 0;
}

function templateId(id) {
  return definitionsByPrefix.get(id.slice(0, -4))?.[0];
}

function editionIds(fromYear, toYear) {
  const validYear = year => Number.isInteger(year) && year >= 1000 && year <= 9999;
  if (!validYear(fromYear) || !validYear(toYear)) throw new Error('invalid competition year range');
  const ids = [];
  for (let year = Math.max(fromYear, 2026); year <= toYear; year++) {
    for (const [id, occurs] of definitions) {
      if (occurs(year)) ids.push(id.slice(0, -4) + year);
    }
  }
  return ids;
}

function editionYear(id) {
  if (typeof id !== 'string' || !/^.+-[0-9]{4}$/.test(id)) return null;
  const definition = definitionsByPrefix.get(id.slice(0, -4));
  const year = Number(id.slice(-4));
  return definition?.[1](year) ? year : null;
}

function firstWeekday(year, month, weekday) {
  const date = Date.UTC(year, month - 1, 1);
  return date + (weekday + 7 - new Date(date).getUTCDay()) % 7 * dayMs;
}

function dayOfYear(start, offset) {
  return new Date(start + offset * dayMs).toISOString().slice(5, 10);
}

function sixNationsCalendar(year) {
  const firstSaturday = firstWeekday(year, 2, 6);
  return sixNationsSchedule.map((matches, round) => {
    const day = dayOfYear(firstSaturday, (round < 3 ? round : round + 1) * 7);
    return matches.map(([, , home, away]) => year % 2 ? [day, null, home, away] : [day, null, away, home]);
  });
}

function nationsCalendar(year) {
  const july = firstWeekday(year, 7, 6);
  const november = firstWeekday(year, 11, 6);
  const alternate = (year - nations.year) % 4 === 2;
  const leagueSchedule = nations.leagueSchedule.map((_, round) => {
    const day = round < 3 ? dayOfYear(july, round * 7) : dayOfYear(november, (round - 3) * 7);
    const sourceRound = alternate ? (round + 3) % 6 : round;
    return nations.leagueSchedule[sourceRound].map(([, , home, away]) =>
      alternate ? [day, null, away, home, null] : [day, null, home, away, null]);
  });
  const finalsSchedule = nations.finalsSchedule.map(([, , placement], i) =>
    [dayOfYear(november, 20 + Math.floor(i / 2)), null, placement]);
  return { leagueSchedule, finalsSchedule };
}

function rugbyChampionshipCalendar(year) {
  const cupYear = isWorldCupYear(year);
  const firstSaturday = firstWeekday(year, cupYear ? 7 : 8, 6);
  const weekOffsets = cupYear ? [0, 1, 3, 4, 5, 6] : [1, 2, 4, 5, 7, 8];
  return trc.schedule.map(([, matches], round) => [
    dayOfYear(firstSaturday, weekOffsets[round] * 7),
    matches.map(([home, away]) => year % 2 ? [home, away] : [away, home]),
  ]);
}

function hostCountryId(year) {
  return year === 2027 ? 'AUS' : year === 2031 ? 'USA' : null;
}

function worldCupGroups(year, random) {
  const groups = Array.from({ length: 6 }, () => []);
  // A reproducible four-band draw from the national teams supported in career.
  for (let offset = 0; offset < defaultRankings.length; offset += 6) {
    const band = defaultRankings.slice(offset, offset + 6);
    for (let i = band.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [band[i], band[j]] = [band[j], band[i]];
    }
    groups.forEach((group, i) => group.push(band[i]));
  }
  const host = hostCountryId(year);
  if (host) {
    const group = groups.find(teams => teams.includes(host));
    const band = group.indexOf(host);
    [groups[0][band], group[band]] = [group[band], groups[0][band]];
    groups[0].splice(band, 1);
    groups[0].unshift(host);
  }
  return [...'ABCDEF'].map((pool, i) => [pool, groups[i]]);
}

function worldCupCalendar(year, groups) {
  const opening = firstWeekday(year, 10, 5);
  const pairings = [[0, 3], [1, 2], [0, 2], [3, 1], [0, 1], [2, 3]];
  const poolSchedule = groups.map(([pool, teams], i) => {
    const offset = i % 2 ? 2 : 1;
    return [pool, pairings.map(([home, away], match) => {
      const days = i === 0 && match === 0 ? 0 : offset + Math.floor(match / 2) * 7;
      return [dayOfYear(opening, days), null, null, teams[home], teams[away]];
    })];
  });
  const anchor = Date.UTC(2027, 9, 1);
  const knockoutSchedule = worldCupKnockoutSchedule.map(([key, day, , , ...bracket]) => {
    const offset = (Date.parse('2027-' + day) - anchor) / dayMs;
    return [key, dayOfYear(opening, offset), null, null, ...bracket];
  });
  return { poolSchedule, knockoutSchedule };
}

function simulatedProvenance(template, year) {
  const base = { calendarStatus: 'simulated' };
  if (template === SIX_NATIONS) return { ...base, releaseWindow: regulation9 };
  if (template === trc.id) return { ...base, cycle: sanzaar, releaseWindow: regulation9 };
  if (template === nations.id) return { ...base, cycle: sanzaar };
  return { ...base, hosts: cupHosts, ...(year === 2031 ? { venueSelection: cup2031Selection } : {}),
    teamsStatus: 'simulated', rankingFallback: 'in-game-order' };
}

module.exports = {
  editionIds, editionYear, templateId, sixNationsCalendar, nationsCalendar, rugbyChampionshipCalendar,
  hostCountryId, worldCupGroups, worldCupCalendar, simulatedProvenance,
};
