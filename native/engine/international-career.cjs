'use strict';

const { hostDossier } = require('./international-hosts.cjs');

function createInternationalCareer(competitions, callups, playerFacts = {}) {
 const facts = playerFacts.players ?? playerFacts;
 const historic = competitions.COMPETITION_IDS.map(id => competitions.createEdition(id));
 const templateCache = new Map(historic.map(edition => [edition.id, edition]));
 const hostCache = new Map();
 const ranking = historic.find(edition => edition.id === 'rugby-world-cup-2027')?.rankings ?? [];
 const nations = new Map(historic.flatMap(edition => edition.teams.map(team => [team.id, team.name])));
 const firstRecurringYear = 2028;
 const lastYear = 2201; // World mode supports up to 175 seasons from 2026.
 const day = 86400000;
 const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
 const yearOf = date => Number(date.slice(0, 4));
 const worldCup = id => id.startsWith('rugby-world-cup-');
 const shift = (date, offset) => new Date(Date.parse(date) + offset * day).toISOString().slice(0, 10);
 const validDate = date => typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) &&
  yearOf(date) >= 2026 && yearOf(date) <= lastYear && Number.isFinite(Date.parse(date)) && shift(date, 0) === date;
 const validId = id => typeof id === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$/.test(id);
 const object = value => value && [Object.prototype, null].includes(Object.getPrototypeOf(value));
 const shape = (value, keys) => object(value) && Object.keys(value).length === keys.length &&
  keys.every(key => Object.hasOwn(value, key));
 const check = (condition, message) => { if (!condition) throw Error(message); };
 const involves = (fixture, nation) => fixture.homeId === nation || fixture.awayId === nation;
 const isActive = (camp, date) => camp.from <= date && date <= camp.through;
 const overlap = (a, b) => a.from <= b.through && b.from <= a.through;
 const sameResult = (a, b) => shape(a, Object.keys(b)) && Object.entries(b).every(([key, value]) => a[key] === value);
 const copy = value => JSON.parse(JSON.stringify(value));
 const campKey = camp => [camp.competitionId, camp.nation, camp.from].join('/');
 const pool = nation => callups.nationalReservePool(nation, 91 - 2.05 * Math.max(0, ranking.indexOf(nation)));
 const isReserve = (id, nation) => new RegExp('^national-' + nation + '-(?:0[1-9]|[12][0-9]|3[0-3])$').test(id);
 const campSize = competitionId => worldCup(competitionId) ? 33 : 30;
 const archiveDate = date => (yearOf(date) - 1) + '-01-01';
 const dateLabel = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeZone: 'UTC' });

 function calendar(state, fromYear, throughYear) {
  const editions = historic.filter(edition => edition.year >= fromYear && edition.year <= throughYear);
  if (state.version === 1) return editions;
  const firstYear = Math.max(fromYear, firstRecurringYear, yearOf(state.recurringFrom));
  if (firstYear > throughYear) return editions;
  for (const id of competitions.editionIds(firstYear, Math.min(throughYear, lastYear))) {
   if (!templateCache.has(id)) templateCache.set(id, competitions.createEdition(id));
   editions.push(templateCache.get(id));
  }
  return editions;
 }

 function resultsFor(state, template) {
  const results = state.version === 1 ? state.results : state.results[template.year] ?? {};
  return Object.fromEntries(template.fixtures.filter(fixture => Object.hasOwn(results, fixture.id))
   .map(fixture => [fixture.id, results[fixture.id]]));
 }

 function hostFor(edition) {
  if (!hostCache.has(edition.id)) hostCache.set(edition.id, hostDossier(edition));
  return hostCache.get(edition.id);
 }

 const family = edition => edition.id.replace(/-\d{4}$/, '');
 function previousEdition(state, edition) {
  return calendar(state, edition.year - 4, edition.year - 1)
   .filter(candidate => family(candidate) === family(edition)).at(-1);
 }

 function hostVisible(state, edition, date) {
  const host = hostFor(edition);
  if (!host) return false;
  if (host.announcementDate <= date) return true;
  const previous = previousEdition(state, edition);
  return !!previous && previous.fixtures.at(-1).date <= date &&
   Object.keys(resultsFor(state, previous)).length === previous.fixtures.length;
 }

 function hostMessage(edition, host, date, guide = false) {
  const countries = host.countries.map(country => country.name).join(', ');
  const location = host.city ? ' Finale à ' + host.city + (host.stadium ? ' · ' + host.stadium : '') + '.' : '';
  const dates = ' Du ' + dateLabel.format(Date.parse(host.opens)) + ' au ' + dateLabel.format(Date.parse(host.ends)) + '.';
  const body = (host.countries.length === 1 ? 'Pays hôte' : 'Pays hôtes') + ' · ' + countries + '.' + dates + location;
  const prefix = guide ? 'host-guide/' : 'host/';
  const title = guide ? 'Votre guide · ' + edition.name : 'Accueil · ' + edition.name;
  return message(prefix + edition.id, 'international_host', title, body, date);
 }

 function hostMail(state, from, to, includeToday) {
  return calendar(state, yearOf(from), yearOf(to) + 3).flatMap(edition => {
   const host = hostFor(edition);
   if (!host || host.announcementDate > to || host.announcementDate < from ||
    (!includeToday && host.announcementDate === from)) return [];
   return [hostMessage(edition, host, host.announcementDate, !!previousEdition(state, edition))];
  }).sort((a, b) => compare(a.date, b.date) || compare(a.id, b.id));
 }

 function announceNextHost(state, completed, date, mail) {
  if (completed.fixtures.some(fixture => !fixture.result)) return;
  const following = calendar(state, completed.year + 1, completed.year + 4)
   .find(edition => family(edition) === family(completed));
  const host = following && hostFor(following);
  if (host) mail.push(hostMessage(following, host, date));
 }

 function restore(state, templates) {
  return templates.map(template => competitions.restoreEdition(template.id, resultsFor(state, template)));
 }

 function storeResult(state, edition, fixtureId, result) {
  (state.results[edition.year] ??= {})[fixtureId] = result;
 }

 function pastThreshold(state, edition) {
  return edition.year < firstRecurringYear ? state.historyBefore : state.recurringFrom;
 }

 function seedHistory(state, templates, through) {
  for (const template of templates) {
   let edition = template;
   for (const fixture of template.fixtures) {
    if (fixture.date >= through) continue;
    const result = competitions.simulateResult(edition, fixture.id, { seed: state.seed });
    edition = competitions.recordResult(edition, fixture.id, result);
    storeResult(state, edition, fixture.id, result);
   }
  }
 }

 function archiveHistory(state, through) {
  const cutoff = archiveDate(through);
  state.callups = state.callups.filter(camp => camp.through >= cutoff);
  state.appearances = state.appearances.filter(row => {
   if (row.date >= cutoff) return true;
   const nation = state.archivedCaps[row.nation] ??= {};
   for (const id of row.playedIds) {
    const bucket = nation[callups.capBucket(id)] ??= {};
    bucket[id] = (Object.hasOwn(bucket, id) ? bucket[id] : 0) + 1;
   }
   return false;
  });
 }

 function windows(editions) {
  return editions.flatMap(edition => edition.teams.flatMap(team => {
   const forTeam = edition.fixtures.filter(fixture => involves(fixture, team.id));
   if (!forTeam.length) return [];
   const cup = worldCup(edition.id);
   const options = cup ? { worldCup: true, openingDate: edition.fixtures[0].date } : undefined;
   const periods = callups.releasePeriods(forTeam, options);
   if (cup) {
    const poolStage = edition.fixtures.filter(fixture => fixture.phase === 'pool');
    if (poolStage.some(fixture => !fixture.result)) {
     const through = shift(poolStage.map(fixture => fixture.date).sort().at(-1), 1);
     periods[0].through = through;
    }
   }
   return periods.map(period => ({ competitionId: edition.id, nation: team.id, ...period }));
  })).sort((a, b) => compare(a.from, b.from) || compare(campKey(a), campKey(b)));
 }

 function knownEligibility(id, nation) {
  if (typeof playerFacts.eligible === 'function') return playerFacts.eligible(id, nation);
  const documented = Object.hasOwn(facts, id) ? facts[id] : null;
  return documented?.seniorNation ? documented.seniorNation === nation :
   documented?.eligibilityNations?.includes(nation) === true;
 }

 function representedNations(state) {
  const represented = new Map();
  for (const [nation, buckets] of Object.entries(state.archivedCaps ?? {})) {
   for (const bucket of Object.values(buckets)) for (const id of Object.keys(bucket)) represented.set(id, nation);
  }
  for (const row of state.appearances) for (const id of row.playedIds) represented.set(id, row.nation);
  return represented;
 }

 function message(id, kind, title, body, date, nation) {
  return { id, kind, title, body, date, action: 'international', nation };
 }

 function openCamps(state, editions, date, players, managedNation, clubPlayerIds, mail, notifyActive = false) {
  const active = windows(editions).filter(camp => isActive(camp, date));
  const priority = camp => Number(camp.nation !== managedNation);
  active.sort((a, b) => compare(a.from, b.from) || priority(a) - priority(b) || compare(campKey(a), campKey(b)));
  let represented;
  for (const camp of active) {
   if (state.callups.some(row => campKey(row) === campKey(camp))) continue;
   represented ??= representedNations(state);
   const unavailableIds = state.callups.filter(row => overlap(row, camp)).flatMap(row => row.playerIds);
   const playerIds = callups.selectCallups({
    players: [...players, ...pool(camp.nation)], nation: camp.nation, date,
    size: campSize(camp.competitionId), unavailableIds,
    isEligible: (player, nation) => knownEligibility(player.id, nation) &&
     (!represented.has(player.id) || represented.get(player.id) === nation),
   });
   state.callups.push({ ...camp, playerIds });
   if (date !== camp.from && !notifyActive) continue;
   const key = campKey(camp);
   const nation = nations.get(camp.nation);
   if (camp.nation === managedNation) mail.push(message(
    'camp/' + key, 'international_callup', 'Votre rassemblement international',
    'La sélection de ' + nation + ' est prête pour la fenêtre.', date, camp.nation
   ));
   const released = playerIds.filter(id => clubPlayerIds.has(id)).length;
   if (released) mail.push(message(
    'club-release/' + key, 'international_release', 'Convocations de votre club',
    released + (released === 1 ? ' joueur rejoint ' : ' joueurs rejoignent ') + nation + '.',
    date, camp.nation
   ));
  }
 }

 function refreshWindows(state, editions) {
  const current = new Map(windows(editions).map(camp => [campKey(camp), camp]));
  state.callups = state.callups.map(camp => {
   const period = current.get(campKey(camp));
   return period && period.through !== camp.through ? { ...camp, through: period.through } : camp;
  });
 }

 function nationalSheet(state, fixture, nation, players, preferredLineup = [], preferredReserves = []) {
  const camp = state.callups.find(row => row.competitionId === fixture.competitionId &&
   row.nation === nation && isActive(row, fixture.date));
  check(camp, 'Rassemblement international introuvable.');
  const reserves = pool(nation);
  const squad = [...players, ...reserves];
  const options = { players: squad, calledIds: camp.playerIds, preferredLineup, preferredReserves };
  let sheet = callups.selectInternationalSheet(options);
  if (!sheet.complete) {
   options.calledIds = [...new Set([...camp.playerIds, ...reserves.map(player => player.id)])];
   sheet = callups.selectInternationalSheet(options);
  }
  check(sheet.complete && preferredLineup.every((id, i) => !id || sheet.lineup[i] === id) &&
   preferredReserves.every((id, i) => !id || sheet.reserves[i] === id), 'Composition internationale invalide.');
  const byId = new Map(squad.map(player => [player.id, player]));
  return { sheet, squad: options.calledIds.map(id => byId.get(id)).filter(Boolean), byId };
 }

 function playFixture(state, edition, fixture, players, preferredNation = null, lineup, reserves) {
  const sides = [fixture.homeId, fixture.awayId].map(nation => {
   const { sheet, byId } = nationalSheet(state, fixture, nation, players,
    nation === preferredNation ? lineup : undefined, nation === preferredNation ? reserves : undefined);
   const strength = sheet.lineup.reduce((sum, id, slot) => {
    const player = byId.get(id);
    return sum + (player.positionRatings?.[slot+1] ?? player.rating) * (0.5 + 0.005 * (player.condition ?? 100));
   }, 0) / 15;
   // Score-only simulation marks which bench players take the field.
   const seedText = state.seed + '/' + fixture.id + '/' + nation;
   const hash = [...seedText].reduce((value, letter) => Math.imul(value ^ letter.charCodeAt(0), 16777619), 2166136261) >>> 0;
   const playedIds = sheet.lineup.concat(sheet.reserves.slice(0, 4 + hash % 5));
   return { nation, sheet, strength, playedIds };
  });
  const result = competitions.simulateResult(edition, fixture.id, {
   seed: state.seed, homeStrength: sides[0].strength, awayStrength: sides[1].strength,
  });
  const updated = competitions.recordResult(edition, fixture.id, result);
  for (const { nation, sheet, playedIds } of sides) callups.recordInternationalAppearances(state.appearances, {
   fixtureId: fixture.id, date: fixture.date, nation, ...sheet, playedIds, completed: true,
  });
  storeResult(state, edition, fixture.id, result);
  return updated;
 }

 function initial(today, seed = 0) {
  check(validDate(today) && Number.isSafeInteger(seed), 'Date ou graine internationale invalide.');
  const state = { version: 2, date: today, historyBefore: today, recurringFrom: today, seed, results: {}, appearances: [], callups: [], archivedCaps: {} };
  seedHistory(state, calendar(state, 2026, yearOf(today)), today);
  return state;
 }

 function upgrade(state) {
  if (state.version === 2) return state;
  validate(state);
  const next = { ...copy(state), version: 2, recurringFrom: state.date, results: {}, archivedCaps: {} };
  for (const template of historic) for (const [id, result] of Object.entries(resultsFor(state, template))) {
   storeResult(next, template, id, result);
  }
  const year = yearOf(state.date);
  if (year >= firstRecurringYear) seedHistory(next, calendar(next, year, year), state.date);
  archiveHistory(next, state.date);
  return next;
 }

 function validate(state, { date } = {}) {
  const legacy = state?.version === 1;
  const keys = ['version', 'date', 'historyBefore', 'seed', 'results', 'appearances', 'callups'];
  check(shape(state, legacy ? keys : keys.concat('recurringFrom', 'archivedCaps')) &&
   (legacy || state.version === 2 && validDate(state.recurringFrom) &&
    state.historyBefore <= state.recurringFrom && state.recurringFrom <= state.date && object(state.archivedCaps)) &&
   validDate(state.date) && validDate(state.historyBefore) &&
   state.historyBefore <= state.date && (date === undefined || state.date === date) &&
   Number.isSafeInteger(state.seed) && object(state.results) &&
   Array.isArray(state.callups) && state.callups.length <= 2000 &&
   Array.isArray(state.appearances) && state.appearances.length <= 2000 &&
   callups.validateInternationalAppearances(state.appearances), 'Historique international invalide.');
  const templates = calendar(state, 2026, legacy ? 2027 : yearOf(state.date));
  const fixtureYears = new Map(templates.flatMap(edition => edition.fixtures.map(fixture => [fixture.id, edition.year])));
  if (legacy) check(Object.keys(state.results).every(id => fixtureYears.has(id)), 'Résultat international invalide.');
  else for (const [year, rows] of Object.entries(state.results)) {
   check(object(rows) && Object.keys(rows).length > 0 &&
    Object.keys(rows).every(id => String(fixtureYears.get(id)) === year), 'Résultat international invalide.');
  }
  const editions = restore(state, templates);
  const all = editions.flatMap(edition => edition.fixtures);
  const byId = new Map(all.map(fixture => [fixture.id, fixture]));
  const expectedHistory = { seed: state.seed, results: {} };
  seedHistory(expectedHistory, templates.filter(edition => edition.year < firstRecurringYear), state.historyBefore);
  if (!legacy) seedHistory(expectedHistory, templates.filter(edition => edition.year >= firstRecurringYear), state.recurringFrom);
  const cutoff = legacy ? '2026-01-01' : archiveDate(state.date);
  const archiveMatches = new Map();
  for (const edition of editions) for (const fixture of edition.fixtures) {
   const { id, date, result } = fixture;
   const threshold = pastThreshold(state, edition);
   const saved = legacy ? state.results[id] : state.results[edition.year]?.[id];
   check(date >= state.date || result, 'Résultat international antérieur manquant.');
   check(!result || date <= state.date && sameResult(saved, result), 'Résultat international invalide.');
   if (date < threshold) check(result && sameResult(result, expectedHistory.results[edition.year]?.[id]), 'Historique international reconstruit invalide.');
   else if (result && date < cutoff) for (const nation of [fixture.homeId, fixture.awayId]) {
    archiveMatches.set(nation, (archiveMatches.get(nation) ?? 0) + 1);
   }
  }
  const expectedCamps = new Map(windows(editions.filter(edition => edition.year >= yearOf(cutoff))).map(camp => [campKey(camp), camp]));
  const seen = new Set();
  const assignments = new Map();
  const campsBySide = new Map();
  const rosterKeys = ['competitionId', 'nation', 'from', 'through', 'playerIds'];
  for (const camp of state.callups) {
   check(shape(camp, rosterKeys) && nations.has(camp.nation), 'Rassemblement international invalide.');
   const key = campKey(camp), expected = expectedCamps.get(key);
   check(expected && !seen.has(key) && camp.from <= state.date && camp.through === expected.through && camp.through >= cutoff &&
    Array.isArray(camp.playerIds) && camp.playerIds.length === campSize(camp.competitionId) &&
    new Set(camp.playerIds).size === camp.playerIds.length && camp.playerIds.every(id => validId(id) &&
     (isReserve(id, camp.nation) || knownEligibility(id, camp.nation))), 'Rassemblement international invalide.');
   seen.add(key);
   const side = camp.competitionId + '/' + camp.nation;
   if (!campsBySide.has(side)) campsBySide.set(side, []);
   campsBySide.get(side).push(camp);
   for (const id of camp.playerIds) {
    if (isReserve(id, camp.nation)) continue;
    const previous = assignments.get(id) ?? [];
    check(!previous.some(row => overlap(row, camp)), 'Deux convocations internationales simultanées.');
    assignments.set(id, previous.concat(camp));
   }
  }
  const recordedSides = new Set();
  const represented = new Map();
  for (const [nation, buckets] of Object.entries(state.archivedCaps ?? {})) {
   check(object(buckets) && archiveMatches.has(nation), 'Archives des sélections invalides.');
   const matches = archiveMatches.get(nation);
   let total = 0;
   for (const [group, bucket] of Object.entries(buckets)) {
    check(object(bucket), 'Archives des sélections invalides.');
    for (const [id, count] of Object.entries(bucket)) {
     check(validId(id) && group === callups.capBucket(id) && Number.isInteger(count) && count >= 1 && count <= matches &&
      !represented.has(id) && (isReserve(id, nation) || knownEligibility(id, nation)), 'Archives des sélections invalides.');
     total += count;
     represented.set(id, nation);
    }
   }
   check(total >= matches * 15 && total <= matches * 23, 'Archives des sélections invalides.');
   archiveMatches.delete(nation);
  }
  check(archiveMatches.size === 0, 'Archives des sélections manquantes.');
  for (const row of state.appearances) {
   const fixture = byId.get(row.fixtureId);
   const template = fixture && templateCache.get(fixture.competitionId);
   const camp = (campsBySide.get(fixture?.competitionId + '/' + row.nation) ?? []).find(camp => isActive(camp, row.date));
   check(fixture?.result && fixture.date === row.date && row.date >= cutoff && row.date >= pastThreshold(state, template) &&
    involves(fixture, row.nation) && camp && row.playedIds.every(id => isReserve(id, row.nation) ||
    camp.playerIds.includes(id) && (!represented.has(id) || represented.get(id) === row.nation)),
   'Participation internationale invalide.');
   for (const id of row.playedIds) represented.set(id, row.nation);
   recordedSides.add(row.fixtureId + '/' + row.nation);
  }
  for (const fixture of all) {
   if (!fixture.result || fixture.date < cutoff || fixture.date < pastThreshold(state, templateCache.get(fixture.competitionId))) continue;
   check([fixture.homeId, fixture.awayId].every(nation => recordedSides.has(fixture.id + '/' + nation)),
    'Participation internationale manquante.');
  }
  return true;
 }

 function advance(state, { from, to, players = [], managedNation = null, clubPlayerIds = [], notifyActive = false }) {
  check(validDate(from) && validDate(to) && from === state.date && from <= to &&
   (managedNation === null || nations.has(managedNation)), 'Avance internationale invalide.');
  const next = copy(upgrade(state));
  const editions = restore(next, calendar(next, yearOf(from) - 1, yearOf(to)));
  const dates = [...new Set([from, to, ...editions.flatMap(edition => edition.fixtures.map(fixture => fixture.date)),
   ...windows(editions).map(camp => camp.from)])].filter(date => from <= date && date <= to).sort();
  const mail = hostMail(next, from, to, notifyActive && from === to);
  const club = new Set(clubPlayerIds);
  const editionsByYear = new Map();
  for (const [index, edition] of editions.entries()) {
   if (!editionsByYear.has(edition.year)) editionsByYear.set(edition.year, []);
   editionsByYear.get(edition.year).push(index);
  }
  let currentYear = yearOf(from);
  for (const date of dates) {
   const year = yearOf(date);
   if (year !== currentYear) {
    archiveHistory(next, date);
    currentYear = year;
   }
   const indices = editionsByYear.get(year) ?? [];
   openCamps(next, indices.map(index => editions[index]), date, players, managedNation, club, mail, notifyActive && date === from);
   if (date === to) break;
   for (const i of indices) {
    const edition = editions[i];
    for (const { id } of edition.fixtures.filter(fixture => fixture.date === date)) {
     const fixture = editions[i].fixtures.find(row => row.id === id);
     if (fixture.result) continue;
     if (managedNation !== null && involves(fixture, managedNation)) {
      const error = Error('Jouez votre match international avant de changer de jour.');
      Object.assign(error, { code: 'INTERNATIONAL_MATCH_PENDING', date, fixtureId: fixture.id });
      throw error;
     }
     check(fixture.homeId && fixture.awayId, 'Rencontre internationale encore sans équipes.');
     editions[i] = playFixture(next, editions[i], fixture, players);
     refreshWindows(next, [editions[i]]);
     announceNextHost(next, editions[i], date, mail);
    }
   }
  }
  next.date = to;
  archiveHistory(next, to);
  mail.sort((a, b) => compare(a.date, b.date));
  return { state: next, mail };
 }

 function play(state, { date, fixtureId, managedNation, players = [], lineup = [], reserves = [] }) {
  check(validDate(date) && date === state.date && nations.has(managedNation), 'Match international indisponible.');
  check(Array.isArray(lineup) && lineup.length <= 15 && Array.isArray(reserves) && reserves.length <= 8 &&
   [...lineup, ...reserves].every(id => id == null || validId(id)), 'Composition internationale invalide.');
  const next = copy(upgrade(state));
  const editions = restore(next, calendar(next, yearOf(date), yearOf(date)));
  const i = editions.findIndex(edition => edition.fixtures.some(fixture => fixture.id === fixtureId));
  const fixture = editions[i]?.fixtures.find(fixture => fixture.id === fixtureId);
  check(fixture?.date === date && fixture.homeId && fixture.awayId && involves(fixture, managedNation),
   'Match international indisponible.');
  if (fixture.result) return { state, mail: [] };
  openCamps(next, editions, date, players, managedNation, new Set(), []);
  editions[i] = playFixture(next, editions[i], fixture, players, managedNation, lineup, reserves);
  refreshWindows(next, [editions[i]]);
  const result = next.results[yearOf(date)][fixture.id];
  const mail = [message('result/' + fixture.id, 'international_result', 'Résultat international',
   nations.get(fixture.homeId) + ' ' + result.home + ' – ' + result.away + ' ' + nations.get(fixture.awayId) + '.',
   date, managedNation)];
  announceNextHost(next, editions[i], date, mail);
  return { state: next, mail };
 }

 function project(state, { date = state.date, players = [], managedNation = null } = {}) {
  const snapshot = copy(upgrade(state));
  const year = yearOf(date);
  const announced = calendar(snapshot, year + 2, year + 4)
   .filter(edition => hostVisible(snapshot, edition, date));
  const editions = restore(snapshot, [...calendar(snapshot, year - 1, year + 1), ...announced]);
  openCamps(snapshot, editions, date, players, managedNation, new Set(), []);
  const competitionViews = editions.map(edition => {
   const host = hostFor(edition);
   return {
    id: edition.id, year: edition.year, name: edition.name, teams: edition.teams, fixtures: edition.fixtures,
    standings: competitions.standings(edition), outcome: competitions.editionOutcome(edition),
    ...(hostVisible(snapshot, edition, date) ? { host } : {}),
   };
  });
  const fixtureList = competitionViews.flatMap(edition => edition.fixtures)
   .sort((a, b) => compare(a.date, b.date) || compare(a.kickoffLocal, b.kickoffLocal));
  const own = managedNation ? fixtureList.filter(fixture => involves(fixture, managedNation)) : [];
  const currentFixture = own.find(fixture => fixture.date === date && fixture.homeId && fixture.awayId) ?? null;
  let nextFixture = own.find(fixture => fixture.date > date && !fixture.result) ?? null;
  if (managedNation && !nextFixture) for (let nextYear = year + 2; nextYear <= Math.min(lastYear, year + 4); nextYear++) {
   const future = calendar(snapshot, nextYear, nextYear).flatMap(edition => edition.fixtures)
    .filter(fixture => involves(fixture, managedNation)).sort((a, b) => compare(a.date, b.date));
   if (future.length) { nextFixture = future[0]; break; }
  }
  const active = snapshot.callups.find(camp => camp.nation === managedNation && isActive(camp, date));
  let squad = [], sheet = null;
  if (active) {
   const selection = nationalSheet(snapshot, currentFixture ?? { competitionId: active.competitionId, date },
    managedNation, players);
   ({ squad, sheet } = selection);
  }
  return {
   date, competitions: competitionViews, fixtures: fixtureList, callups: snapshot.callups,
   releaseWindows: windows(editions),
   appearances: snapshot.appearances, currentFixture, nextFixture, squad: squad.map(player => ({
    id: player.id, name: player.name, pos: player.pos, fam: player.fam, age: player.age,
    rating: player.rating, condition: player.condition, injury: player.injury,
    nationalReserve: !!player.nationalReserve,
   })), sheet, choicesBySlot: sheet ? callups.selectInternationalChoices(squad) : null,
  };
 }

 function currentFixture(state, nation) {
  if (!nation) return null;
  const year = yearOf(state.date);
  const active = calendar(state, year, year).filter(edition => edition.fixtures.some(fixture => fixture.date === state.date));
  return restore(state, active).flatMap(edition => edition.fixtures)
   .find(fixture => fixture.date === state.date && !fixture.result && involves(fixture, nation)) ?? null;
 }

 return Object.freeze({ initial, upgrade, validate, advance, play, project, currentFixture });
}

module.exports = { createInternationalCareer };
