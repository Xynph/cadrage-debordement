'use strict';

// Calendrier international seniors complémentaire (décision de Léo du 13/11/2026) :
// chaque sélection joue à peu près le même nombre de rencontres par an, chaque
// année, même sur une carrière de vingt ans. Les vraies compétitions passent
// d'abord (World Rugby Nations Cup, Pacific Nations Cup, Rugby Europe
// Championship, tournées des Lions, tournées Nouvelle-Zélande – Afrique du Sud) ;
// les fenêtres restantes (tournées d'été, tests de novembre, préparation de la
// Coupe du monde, tests de février des nations hors Tournoi) reçoivent des tests
// crédibles, choisis de façon reproductible à partir de l'année seule.

const { teamNames, defaultRankings } = require('./international-2027.cjs');
const { releasePeriods } = require('./international-callups.cjs');

const LIONS = 'BIL';
const HOME_UNIONS = Object.freeze(['ENG', 'IRE', 'SCO', 'WAL']);
const TARGET_MATCHES = 12;
const names = Object.freeze({ ...teamNames, [LIONS]: 'Lions britanniques et irlandais' });
const north = new Set(['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL', 'GEO', 'ESP', 'POR', 'ROU']);
const sixNations = new Set(['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL']);
const sanzaar = new Set(['NZL', 'RSA', 'AUS', 'ARG']);
// Février–mars : seules les nations d'Europe et des Amériques hors Tournoi jouent
// (Rugby Europe, ancien Americas Rugby Championship) ; le Pacifique, le Japon et
// l'hémisphère Sud sont alors en saison de club.
const februaryNations = new Set(['GEO', 'ESP', 'POR', 'ROU', 'URU', 'CHI', 'USA', 'CAN']);
const sameBloc = (a, b) => (sixNations.has(a) && sixNations.has(b)) || (sanzaar.has(a) && sanzaar.has(b));
const dayMs = 86400000;

const sources = {
  nationsCup: 'https://www.world.rugby/news/1043086/everything-you-need-to-know-about-the-world-rugby-nations-cup',
  pacificNationsCup2026: 'https://eagles.rugby/news/dates-set-for-reformatted-2026-pacific-nations-cup-2026819',
  rugbyEurope: 'https://www.rugbyeurope.eu/competitions/rugby-europe-championship',
  lions: 'https://www.lionsrugby.com/',
  sanzaar: 'https://springboks.rugby/news-features/articles/2025/10/16/sanzaar-confirms-exciting-calendar-for-2026-2030',
  regulation9: 'https://www.world.rugby/organisation/governance/regulations/reg-9',
};

const isWorldCupYear = year => year >= 2027 && (year - 2027) % 4 === 0;
const lionsHost = year => ['NZL', 'RSA', 'AUS'][((year - 2029) / 4) % 3];

const families = {
  'nations-cup': { name: 'World Rugby Nations Cup', occurs: year => year >= 2026 && year % 2 === 0 },
  'pacific-nations-cup': { name: 'Pacific Nations Cup', occurs: year => year >= 2026 },
  'rugby-europe-championship': { name: 'Rugby Europe Championship', occurs: year => year >= 2027 },
  'lions-tour': { name: 'Tournée des Lions britanniques et irlandais', occurs: year => year >= 2029 && (year - 2029) % 4 === 0 },
  'greatest-rivalry': { name: 'Rugby’s Greatest Rivalry', occurs: year => year === 2026 || year === 2030 },
  'test-matches': { name: 'Tests internationaux', occurs: year => year >= 2026 },
};
const FAMILY_IDS = Object.freeze(Object.keys(families));

function familyOf(id) {
  if (typeof id !== 'string' || !/^.+-[0-9]{4}$/.test(id)) return null;
  const family = id.slice(0, -5);
  return Object.hasOwn(families, family) ? family : null;
}

function yearOf(id) {
  const family = familyOf(id);
  if (!family) return null;
  const year = Number(id.slice(-4));
  return families[family].occurs(year) ? year : null;
}

function editionIds(fromYear, toYear) {
  const ids = [];
  for (let year = Math.max(fromYear, 2026); year <= toYear; year++) {
    for (const family of FAMILY_IDS) if (families[family].occurs(year)) ids.push(family + '-' + year);
  }
  return ids;
}

function familyName(id) {
  const family = familyOf(id);
  return family ? families[family].name + ' ' + id.slice(-4) : null;
}

function utc(date) { return Date.parse(date + 'T00:00:00Z'); }
function iso(ms) { return new Date(ms).toISOString().slice(0, 10); }
function shift(date, days) { return iso(utc(date) + days * dayMs); }
function saturday(year, month, index = 0) {
  const first = Date.UTC(year, month - 1, 1);
  return iso(first + ((6 + 7 - new Date(first).getUTCDay()) % 7 + index * 7) * dayMs);
}
function lastSaturday(year, month) {
  const last = Date.UTC(year, month, 0);
  return iso(last - ((new Date(last).getUTCDay() + 1) % 7) * dayMs);
}

function hash(text) {
  let state = 2166136261;
  for (const letter of String(text)) state = Math.imul(state ^ letter.codePointAt(0), 16777619);
  return state >>> 0;
}

const rank = id => {
  const i = defaultRankings.indexOf(id);
  return i < 0 ? 0 : i;
};

// Ronde unique à n équipes (méthode du cercle), domicile alterné.
function roundRobin(teams, salt) {
  const list = teams.slice();
  if (list.length % 2) list.push(null);
  const rounds = [];
  for (let r = 0; r < list.length - 1; r++) {
    const matches = [];
    for (let i = 0; i < list.length / 2; i++) {
      const a = list[i], b = list[list.length - 1 - i];
      if (!a || !b) continue;
      const swap = (r + i + hash(salt + a + b)) % 2;
      matches.push(swap ? [b, a] : [a, b]);
    }
    rounds.push(matches);
    list.splice(1, 0, list.pop());
  }
  return rounds;
}

function fixture(competitionId, key, date, round, phase, pool, homeId, awayId, extra = {}) {
  return {
    id: competitionId + '-' + key, competitionId, date, kickoffLocal: null, round, phase, pool,
    homeId, awayId, neutralVenue: false, venue: null, result: null, dateStatus: 'simulated', ...extra,
  };
}

function edition(id, groups, fixtures, provenance, extra = {}) {
  const year = Number(id.slice(-4));
  const teamIds = [...new Set(groups.flatMap(([, ids]) => ids))];
  return {
    id, name: familyName(id), year,
    teams: teamIds.map(team => ({ id: team, name: names[team] })),
    rankings: [...defaultRankings, LIONS].filter(team => teamIds.includes(team)),
    fixtures: fixtures.sort((a, b) => a.date.localeCompare(b.date) || a.id.localeCompare(b.id)),
    groups, provenance: { calendarStatus: 'simulated', ...provenance }, ...extra,
  };
}

// Deux poules géographiques de six, cinq journées (trois en juillet, deux en
// novembre) ; pas de finale en 2026 et 2028 : un vainqueur par poule.
function nationsCup(id, year) {
  const pools = [
    ['americas-pacific', ['USA', 'URU', 'CAN', 'CHI', 'SAM', 'TGA']],
    ['europe-africa-asia', ['GEO', 'ESP', 'ROU', 'POR', 'HKG', 'ZIM']],
  ];
  const dates = [saturday(year, 7, 0), saturday(year, 7, 1), saturday(year, 7, 2), saturday(year, 11, 0), saturday(year, 11, 1)];
  const neutralHomes = new Set(['SAM', 'TGA', 'HKG', 'ZIM']);
  const fixtures = pools.flatMap(([pool, teams]) => roundRobin(teams, id + pool).flatMap((matches, r) =>
    matches.map(([home, away], i) => fixture(id, pool + '-r' + (r + 1) + '-' + (i + 1), dates[r], r + 1, 'pool', pool,
      home, away, { neutralVenue: neutralHomes.has(home) }))));
  return edition(id, pools, fixtures, { calendar: sources.nationsCup, format: 'two-pool-champions' }, { poolChampions: true });
}

function pacificNationsCup(id, year) {
  if (year === 2026) {
    const fixtures = [
      fixture(id, 'sf-1', '2026-09-12', 1, 'semi-final', null, 'FIJ', 'CAN', { venue: 'Hanazono Rugby Stadium', neutralVenue: true, dateStatus: 'official' }),
      fixture(id, 'sf-2', '2026-09-12', 1, 'semi-final', null, 'JPN', 'USA', { venue: 'Hanazono Rugby Stadium', dateStatus: 'official' }),
      fixture(id, 'bronze-final', '2026-09-19', 2, 'bronze-final', null, null, null,
        { venue: 'Prince Chichibu Memorial Stadium', neutralVenue: true, dateStatus: 'official', homeSource: 'L:sf-1', awaySource: 'L:sf-2' }),
      fixture(id, 'final', '2026-09-19', 2, 'final', null, null, null,
        { venue: 'Prince Chichibu Memorial Stadium', neutralVenue: true, dateStatus: 'official', homeSource: 'W:sf-1', awaySource: 'W:sf-2' }),
    ];
    return edition(id, [[null, ['FIJ', 'JPN', 'CAN', 'USA']]], fixtures, { calendar: sources.pacificNationsCup2026, calendarStatus: 'official' });
  }
  const pools = [['pacific', ['FIJ', 'SAM', 'TGA']], ['pan-pacific', ['JPN', 'CAN', 'USA']]];
  const start = isWorldCupYear(year) ? saturday(year, 7, 0) : lastSaturday(year, 8);
  const fixtures = pools.flatMap(([pool, teams]) => roundRobin(teams, id + pool).flatMap((matches, r) =>
    matches.map(([home, away], i) => fixture(id, pool + '-r' + (r + 1) + '-' + (i + 1), shift(start, 7 * r), r + 1, 'pool', pool, home, away))));
  const finals = shift(start, 21);
  fixtures.push(
    fixture(id, 'placement-5', finals, 4, 'placement', null, null, null, { neutralVenue: true, placement: 5, homeSource: 'pool:pacific:3', awaySource: 'pool:pan-pacific:3' }),
    fixture(id, 'bronze-final', finals, 4, 'bronze-final', null, null, null, { neutralVenue: true, homeSource: 'pool:pacific:2', awaySource: 'pool:pan-pacific:2' }),
    fixture(id, 'final', finals, 4, 'final', null, null, null, { neutralVenue: true, homeSource: 'pool:pacific:1', awaySource: 'pool:pan-pacific:1' }),
  );
  return edition(id, pools, fixtures, { cycle: sources.pacificNationsCup2026 });
}

// Les autres nations du championnat (Belgique, Pays-Bas, Allemagne, Suisse…)
// ne font pas partie des 24 sélections du jeu : la compétition garde ses quatre
// têtes d'affiche, une phase de poule puis la finale et la troisième place.
function rugbyEurope(id, year) {
  const teams = ['GEO', 'ESP', 'POR', 'ROU'];
  const start = saturday(year, 2, 0);
  const weeks = [0, 1, 3];
  const fixtures = roundRobin(teams, id).flatMap((matches, r) =>
    matches.map(([home, away], i) => fixture(id, 'r' + (r + 1) + '-' + (i + 1), shift(start, 7 * weeks[r]), r + 1, 'pool', null, home, away)));
  const finals = shift(start, 35);
  fixtures.push(
    fixture(id, 'bronze-final', finals, 4, 'bronze-final', null, null, null, { homeSource: 'pool::3', awaySource: 'pool::4' }),
    fixture(id, 'final', finals, 4, 'final', null, null, null, { homeSource: 'pool::1', awaySource: 'pool::2' }),
  );
  return edition(id, [[null, teams]], fixtures, { calendar: sources.rugbyEurope });
}

// Rotation Nouvelle-Zélande (2029), Afrique du Sud (2033), Australie (2037)…
// Trois tests en juillet, avant le Rugby Championship.
function lionsTour(id, year) {
  const host = lionsHost(year);
  const fixtures = [1, 2, 3].map(n => fixture(id, 'test-' + n, saturday(year, 7, n), n, 'test', null, host, LIONS));
  return edition(id, [[null, [host, LIONS]]], fixtures, { calendar: sources.lions }, { series: true });
}

// Tournées de quatre tests entre All Blacks et Springboks (SANZAAR 2026-2030),
// en Nouvelle-Zélande en 2026 et en Afrique du Sud en 2030.
function greatestRivalry(id, year) {
  const host = year === 2026 ? 'NZL' : 'RSA';
  const away = host === 'NZL' ? 'RSA' : 'NZL';
  const start = saturday(year, 8, 2);
  const fixtures = [0, 1, 2, 3].map(n => fixture(id, 'test-' + (n + 1), shift(start, 7 * n), n + 1, 'test', null, host, away));
  return edition(id, [[null, [host, away]]], fixtures, { cycle: sources.sanzaar }, { series: true });
}

// --- Tests complémentaires -------------------------------------------------

const windowLabels = {
  february: 'Tests de février', summer: 'Tournée d’été', warmup: 'Préparation de la Coupe du monde',
  autumn: 'Fin d’été', november: 'Tests de novembre',
};

function fillWindows(year) {
  const saturdays = (month, from = 0, count = 5) => Array.from({ length: count }, (_, i) => saturday(year, month, from + i))
    .filter(date => Number(date.slice(5, 7)) === month);
  const cup = isWorldCupYear(year);
  const windows = [];
  if (year > 2026) windows.push({ key: 'february', dates: [...saturdays(2), ...saturdays(3, 0, 2)], cap: 3, eligible: id => februaryNations.has(id) });
  windows.push({ key: cup ? 'warmup' : 'summer', dates: saturdays(7), cap: 3, eligible: () => true });
  windows.push({ key: cup ? 'warmup' : 'autumn', dates: [...saturdays(8), ...saturdays(9)], cap: cup ? 3 : 4,
    eligible: id => cup || !sixNations.has(id) });
  if (!cup) windows.push({ key: 'november', dates: saturdays(11), cap: 4, eligible: () => true });
  return windows;
}

// Nombre attendu de rencontres déjà prévues (phases finales comprises).
function expectedCounts(editions) {
  const counts = new Map();
  const add = (id, n = 1) => { if (id && id !== LIONS) counts.set(id, (counts.get(id) ?? 0) + n); };
  for (const e of editions) {
    const cup = e.id.startsWith('rugby-world-cup-');
    for (const f of e.fixtures) { add(f.homeId); add(f.awayId); }
    if (cup) for (const { id } of e.teams) { const r = rank(id); add(id, r < 4 ? 3 : r < 8 ? 2 : r < 16 ? 1 : 0); }
    else {
      const unresolved = e.fixtures.filter(f => !f.homeId).length;
      if (unresolved) for (const { id } of e.teams) add(id, Math.min(1, unresolved));
    }
  }
  return counts;
}

function busyPeriods(editions) {
  const busy = new Map();
  const push = (id, period) => { if (!busy.has(id)) busy.set(id, []); busy.get(id).push(period); };
  for (const e of editions) {
    const cup = e.id.startsWith('rugby-world-cup-');
    for (const { id } of e.teams) {
      const own = cup || e.fixtures.some(f => !f.homeId) ? e.fixtures.filter(f => !f.homeId || f.homeId === id || f.awayId === id)
        : e.fixtures.filter(f => f.homeId === id || f.awayId === id);
      if (!own.length) continue;
      const periods = cup ? [{ from: shift(e.fixtures[0].date, -36), through: shift(e.fixtures.at(-1).date, 1) }]
        : releasePeriods(own);
      for (const period of periods) {
        push(id, period);
        if (id === LIONS) for (const union of HOME_UNIONS) push(union, { from: shift(period.from, -7), through: period.through });
      }
    }
  }
  return busy;
}

function testMatches(id, year, baseEditions) {
  const counts = expectedCounts(baseEditions);
  const busy = busyPeriods(baseEditions);
  const nations = defaultRankings.slice();
  const fixtures = [];
  const meetings = new Map();
  const pairKey = (a, b) => [a, b].sort().join('/');
  for (const e of baseEditions) for (const f of e.fixtures) if (f.homeId && f.awayId) {
    const key = pairKey(f.homeId, f.awayId);
    meetings.set(key, (meetings.get(key) ?? 0) + 1);
  }
  const free = (nation, date) => {
    const camp = { from: shift(date, -6), through: shift(date, 1) };
    return !(busy.get(nation) ?? []).some(p => p.from <= camp.through && camp.from <= p.through);
  };
  for (const window of fillWindows(year)) {
    const used = new Map();
    const series = new Map();
    for (const date of window.dates) {
      const candidates = nations.filter(n => window.eligible(n) && (counts.get(n) ?? 0) < TARGET_MATCHES &&
        (used.get(n) ?? 0) < window.cap && free(n, date))
        .sort((a, b) => (counts.get(a) ?? 0) - (counts.get(b) ?? 0) || hash(id + date + a) - hash(id + date + b));
      const taken = new Set();
      for (const a of candidates) {
        if (taken.has(a)) continue;
        let best = null, bestScore = -Infinity;
        for (const b of candidates) {
          if (b === a || taken.has(b)) continue;
          const gap = Math.abs(rank(a) - rank(b));
          if (gap > 12 || (window.key !== 'warmup' && sameBloc(a, b))) continue;
          const key = pairKey(a, b);
          const cross = north.has(a) !== north.has(b);
          let score = -gap + (hash(id + date + key) % 4);
          if (window.key !== 'february' && cross) score += 6;
          if (series.get(a) === b && window.key === 'summer') score += 9;
          score -= 7 * (meetings.get(key) ?? 0);
          if (score > bestScore) { best = b; bestScore = score; }
        }
        if (!best) continue;
        taken.add(a); taken.add(best);
        const [x, y] = [a, best];
        let home;
        if (north.has(x) !== north.has(y)) home = window.key === 'november' || window.key === 'february' ? (north.has(x) ? x : y) : (north.has(x) ? y : x);
        else home = series.get(x) === y ? (fixtures.findLast(f => pairKey(f.homeId, f.awayId) === pairKey(x, y))?.homeId ?? x)
          : (hash(id + pairKey(x, y)) % 2 ? x : y);
        const away = home === x ? y : x;
        fixtures.push(fixture(id, date.slice(5).replace('-', '') + '-' + home + '-' + away, date, fixtures.length + 1, 'test', null,
          home, away, { window: window.key, windowName: windowLabels[window.key] }));
        for (const n of [x, y]) {
          counts.set(n, (counts.get(n) ?? 0) + 1);
          used.set(n, (used.get(n) ?? 0) + 1);
        }
        series.set(x, y); series.set(y, x);
        const key = pairKey(x, y);
        meetings.set(key, (meetings.get(key) ?? 0) + 1);
      }
    }
  }
  fixtures.forEach((f, i) => { f.round = i + 1; });
  return edition(id, [[null, [...new Set(fixtures.flatMap(f => [f.homeId, f.awayId]))]]], fixtures,
    { releaseWindow: sources.regulation9, opponents: 'simulated' }, { friendly: true });
}

const builders = {
  'nations-cup': nationsCup, 'pacific-nations-cup': pacificNationsCup, 'rugby-europe-championship': rugbyEurope,
  'lions-tour': lionsTour, 'greatest-rivalry': greatestRivalry,
};

// baseEditions(year) : éditions déjà fixées de l'année (hors tests complémentaires).
function createExtraEdition(id, baseEditions) {
  const year = yearOf(id);
  if (year === null) throw new Error('unknown international competition: ' + id);
  const family = familyOf(id);
  if (family === 'test-matches') return testMatches(id, year, baseEditions(year));
  return builders[family](id, year);
}

module.exports = {
  LIONS, HOME_UNIONS, TARGET_MATCHES, FAMILY_IDS, names, familyOf, yearOf, editionIds, familyName,
  createExtraEdition, expectedCounts, lionsHost,
};
