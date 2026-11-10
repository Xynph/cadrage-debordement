'use strict';

function createInternationalCareer(competitions, callups, playerFacts = {}) {
 const cupId = 'rugby-world-cup-2027';
 const facts = playerFacts.players ?? playerFacts;
 const templates = competitions.COMPETITION_IDS.map(id => competitions.createEdition(id));
 const fixtures = templates.flatMap(edition => edition.fixtures);
 const fixtureIds = new Set(fixtures.map(fixture => fixture.id));
 const ranking = templates.find(edition => edition.id === cupId)?.rankings ?? [];
 const nations = new Map(templates.flatMap(edition => edition.teams.map(team => [team.id, team.name])));
 const day = 86400000;
 const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
 const shift = (date, offset) => new Date(Date.parse(date) + offset * day).toISOString().slice(0, 10);
 const validDate = date => typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date) &&
  Number.isFinite(Date.parse(date)) && shift(date, 0) === date;
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
 const campSize = competitionId => competitionId === cupId ? 33 : 30;

 function restore(results) {
  return templates.map(template => competitions.restoreEdition(template.id, Object.fromEntries(
   template.fixtures.filter(fixture => Object.hasOwn(results, fixture.id)).map(fixture => [fixture.id, results[fixture.id]])
  )));
 }

 function windows(editions) {
  return editions.flatMap(edition => edition.teams.flatMap(team => {
   const forTeam = edition.fixtures.filter(fixture => involves(fixture, team.id));
   if (!forTeam.length) return [];
   const worldCup = edition.id === cupId;
   const options = worldCup ? { worldCup, openingDate: edition.fixtures[0].date } : undefined;
   const periods = callups.releasePeriods(forTeam, options);
   if (worldCup) {
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

 function eligible(state, id, nation) {
  if (!knownEligibility(id, nation)) return false;
  const first = state.appearances.find(row => row.playedIds.includes(id));
  return !first || first.nation === nation;
 }

 function message(id, kind, title, body, date, nation) {
  return { id, kind, title, body, date, action: 'international', nation };
 }

 function openCamps(state, editions, date, players, managedNation, clubPlayerIds, mail) {
  const active = windows(editions).filter(camp => isActive(camp, date));
  const priority = camp => Number(camp.nation !== managedNation);
  active.sort((a, b) => compare(a.from, b.from) || priority(a) - priority(b) || compare(campKey(a), campKey(b)));
  for (const camp of active) {
   if (state.callups.some(row => campKey(row) === campKey(camp))) continue;
   const unavailableIds = state.callups.filter(row => overlap(row, camp)).flatMap(row => row.playerIds);
   const playerIds = callups.selectCallups({
    players: [...players, ...pool(camp.nation)], nation: camp.nation, date,
    size: campSize(camp.competitionId), unavailableIds,
    isEligible: (player, nation) => eligible(state, player.id, nation),
   });
   state.callups.push({ ...camp, playerIds });
   if (date !== camp.from) continue;
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
   const strength = sheet.lineup.reduce((sum, id) => {
    const player = byId.get(id);
    return sum + player.rating * (0.5 + 0.005 * (player.condition ?? 100));
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
  state.results[fixture.id] = result;
  return updated;
 }

 function initial(today, seed = 0) {
  check(validDate(today) && Number.isSafeInteger(seed), 'Date ou graine internationale invalide.');
  const state = { version: 1, date: today, historyBefore: today, seed, results: {}, appearances: [], callups: [] };
  for (const template of templates) {
   let edition = competitions.createEdition(template.id);
   for (const original of template.fixtures) {
    if (original.date >= today) continue;
    const result = competitions.simulateResult(edition, original.id, { seed });
    edition = competitions.recordResult(edition, original.id, result);
    state.results[original.id] = result;
   }
  }
  return state;
 }

 function validate(state, { date } = {}) {
  check(shape(state, ['version', 'date', 'historyBefore', 'seed', 'results', 'appearances', 'callups']) &&
   state.version === 1 && validDate(state.date) && validDate(state.historyBefore) &&
   state.historyBefore <= state.date && (date === undefined || state.date === date) &&
   Number.isSafeInteger(state.seed) && object(state.results) &&
   Object.keys(state.results).every(id => fixtureIds.has(id)) && Array.isArray(state.callups) &&
   Array.isArray(state.appearances) && state.appearances.length <= fixtures.length * 2 &&
   callups.validateInternationalAppearances(state.appearances), 'Historique international invalide.');
  const editions = restore(state.results);
  const all = editions.flatMap(edition => edition.fixtures);
  const byId = new Map(all.map(fixture => [fixture.id, fixture]));
  const expectedHistory = initial(state.historyBefore, state.seed).results;
  for (const fixture of all) {
   const { id, date, result } = fixture;
   check(date >= state.date || result, 'Résultat international antérieur manquant.');
   check(!result || date <= state.date && sameResult(state.results[id], result), 'Résultat international invalide.');
   if (date < state.historyBefore) check(sameResult(result, expectedHistory[id]), 'Historique international reconstruit invalide.');
  }
  const expectedCamps = new Map(windows(editions).map(camp => [campKey(camp), camp]));
  const seen = new Set();
  const assignments = new Map();
  const rosterKeys = ['competitionId', 'nation', 'from', 'through', 'playerIds'];
  for (const camp of state.callups) {
   check(shape(camp, rosterKeys) && nations.has(camp.nation), 'Rassemblement international invalide.');
   const key = campKey(camp), expected = expectedCamps.get(key);
   check(expected && !seen.has(key) && camp.from <= state.date && camp.through === expected.through &&
    Array.isArray(camp.playerIds) && camp.playerIds.length === campSize(camp.competitionId) &&
    new Set(camp.playerIds).size === camp.playerIds.length && camp.playerIds.every(id => validId(id) &&
     (isReserve(id, camp.nation) || knownEligibility(id, camp.nation))), 'Rassemblement international invalide.');
   seen.add(key);
   for (const id of camp.playerIds) {
    if (isReserve(id, camp.nation)) continue;
    const previous = assignments.get(id) ?? [];
    check(!previous.some(row => overlap(row, camp)), 'Deux convocations internationales simultanées.');
    assignments.set(id, previous.concat(camp));
   }
  }
  const recordedSides = new Set();
  const represented = new Map();
  for (const row of state.appearances) {
   const fixture = byId.get(row.fixtureId);
   const camp = state.callups.find(camp => camp.competitionId === fixture?.competitionId &&
    camp.nation === row.nation && isActive(camp, row.date));
   check(fixture?.result && fixture.date === row.date && row.date >= state.historyBefore &&
    involves(fixture, row.nation) && camp && row.playedIds.every(id => isReserve(id, row.nation) ||
    camp.playerIds.includes(id) && (!represented.has(id) || represented.get(id) === row.nation)),
   'Participation internationale invalide.');
   for (const id of row.playedIds) represented.set(id, row.nation);
   recordedSides.add(row.fixtureId + '/' + row.nation);
  }
  for (const fixture of all) {
   if (!fixture.result || fixture.date < state.historyBefore) continue;
   check([fixture.homeId, fixture.awayId].every(nation => recordedSides.has(fixture.id + '/' + nation)),
    'Participation internationale manquante.');
  }
  return true;
 }

 function advance(state, { from, to, players = [], managedNation = null, clubPlayerIds = [] }) {
  check(validDate(from) && validDate(to) && from === state.date && from <= to &&
   (managedNation === null || nations.has(managedNation)), 'Avance internationale invalide.');
  const next = copy(state);
  const editions = restore(next.results);
  const dates = [...new Set([from, to, ...fixtures.map(fixture => fixture.date),
   ...windows(editions).map(camp => camp.from)])].filter(date => from <= date && date <= to).sort();
  const mail = [];
  const club = new Set(clubPlayerIds);
  for (const date of dates) {
   openCamps(next, editions, date, players, managedNation, club, mail);
   if (date === to) break;
   for (const [i, edition] of editions.entries()) {
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
     refreshWindows(next, editions);
    }
   }
  }
  next.date = to;
  return { state: next, mail };
 }

 function play(state, { date, fixtureId, managedNation, players = [], lineup = [], reserves = [] }) {
  check(validDate(date) && date === state.date && nations.has(managedNation), 'Match international indisponible.');
  check(Array.isArray(lineup) && lineup.length <= 15 && Array.isArray(reserves) && reserves.length <= 8 &&
   [...lineup, ...reserves].every(id => id == null || validId(id)), 'Composition internationale invalide.');
  const next = copy(state);
  const editions = restore(next.results);
  const i = editions.findIndex(edition => edition.fixtures.some(fixture => fixture.id === fixtureId));
  const fixture = editions[i]?.fixtures.find(fixture => fixture.id === fixtureId);
  check(fixture?.date === date && fixture.homeId && fixture.awayId && involves(fixture, managedNation),
   'Match international indisponible.');
  if (fixture.result) return { state, mail: [] };
  openCamps(next, editions, date, players, managedNation, new Set(), []);
  editions[i] = playFixture(next, editions[i], fixture, players, managedNation, lineup, reserves);
  refreshWindows(next, editions);
  const result = next.results[fixture.id];
  const mail = [message('result/' + fixture.id, 'international_result', 'Résultat international',
   nations.get(fixture.homeId) + ' ' + result.home + ' – ' + result.away + ' ' + nations.get(fixture.awayId) + '.',
   date, managedNation)];
  return { state: next, mail };
 }

 function project(state, { date = state.date, players = [], managedNation = null } = {}) {
  const snapshot = copy(state);
  const editions = restore(snapshot.results);
  openCamps(snapshot, editions, date, players, managedNation, new Set(), []);
  const competitionViews = editions.map(edition => ({
   id: edition.id, name: edition.name, teams: edition.teams, fixtures: edition.fixtures,
   standings: competitions.standings(edition), outcome: competitions.editionOutcome(edition),
  }));
  const calendar = competitionViews.flatMap(edition => edition.fixtures)
   .sort((a, b) => compare(a.date, b.date) || compare(a.kickoffLocal, b.kickoffLocal));
  const own = managedNation ? calendar.filter(fixture => involves(fixture, managedNation)) : [];
  const currentFixture = own.find(fixture => fixture.date === date && fixture.homeId && fixture.awayId) ?? null;
  const nextFixture = own.find(fixture => fixture.date > date && !fixture.result) ?? null;
  const active = snapshot.callups.find(camp => camp.nation === managedNation && isActive(camp, date));
  let squad = [], sheet = null;
  if (active) {
   const selection = nationalSheet(snapshot, currentFixture ?? { competitionId: active.competitionId, date },
    managedNation, players);
   ({ squad, sheet } = selection);
  }
  return {
   date, competitions: competitionViews, fixtures: calendar, callups: snapshot.callups,
   appearances: snapshot.appearances, currentFixture, nextFixture, squad: squad.map(player => ({
    id: player.id, name: player.name, pos: player.pos, fam: player.fam, age: player.age,
    rating: player.rating, condition: player.condition, injury: player.injury,
    nationalReserve: !!player.nationalReserve,
   })), sheet,
  };
 }

 return Object.freeze({ initial, validate, advance, play, project });
}

module.exports = { createInternationalCareer };
