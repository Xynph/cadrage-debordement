'use strict';

function factory() {
 const positions = [
  'Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne',
  'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture',
  'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière',
 ];
 const families = [0, 1, 0, 2, 2, 3, 3, 3, 4, 5, 6, 7, 7, 6, 8];
 const cover = [1, 0, 2, 3, 5, 8, 9, 10];
 const day = 86400000;
 const validNation = value => typeof value === 'string' && /^[A-Z]{3}$/.test(value);
 const validId = value => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$/.test(value);
 const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
  Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
 const compareText = (a, b) => a < b ? -1 : a > b ? 1 : 0;
 const unique = values => new Set(values).size === values.length;
 const fit = p => Number.isFinite(p.rating) && (p.age === undefined || p.age >= 18) && !p.injury && !p.suspension;
 const formScore = p => p.rating * (0.5 + (p.condition ?? 100) * 0.005);
 const byForm = (a, b) => Number(!!a.nationalReserve) - Number(!!b.nationalReserve) ||
  formScore(b) - formScore(a) || compareText(a.id, b.id);

 function isSlotEligible(player, slot) {
  const i = slot < 15 ? slot : cover[slot - 15];
  if (player.positionRatings && i < 3 && Array.isArray(player.qualifiedFrontRowPositions)) return player.qualifiedFrontRowPositions.includes(i + 1);
  if (player.positionRatings && i >= 3) return true;
  if (i === 0 || i === 2) {
   return player.pos === positions[i] || player.nationaleQualifications?.includes(positions[i]);
  }
  if (slot === 21) return player.fam >= 4;
  if (slot === 22) return player.fam >= 6;
  return player.fam === families[i] || player.nationaleQualifications?.some(pos => families[positions.indexOf(pos)] === families[i]);
 }

 function sheetOptions(players, calledIds) {
  const called = new Set(calledIds);
  const pool = players.filter(p => called.has(p.id) && fit(p)).sort(byForm);
  return Array.from({ length: 23 }, (_, slot) => pool.filter(player => isSlotEligible(player, slot)).sort((a,b)=>{
   const number=(slot<15?slot:cover[slot-15])+1;
   const score=p=>(p.positionRatings?.[number]??p.rating)*(0.5+(p.condition??100)*0.005);
   return Number(!!a.nationalReserve)-Number(!!b.nationalReserve)||score(b)-score(a)||compareText(a.id,b.id);
  }));
 }

 function selectInternationalChoices(players) {
  const choices = sheetOptions(players, players.map(player => player.id)).map(slot => slot.map(player => player.id));
  return { lineup: choices.slice(0, 15), reserves: choices.slice(15) };
 }

 function selectInternationalSheet({ players, calledIds, preferredLineup = [], preferredReserves = [] }) {
  const preferences = Array.from({ length: 23 }, (_, slot) => slot < 15 ? preferredLineup[slot] : preferredReserves[slot - 15]);
  const options = sheetOptions(players, calledIds);
  const assigned = new Map();
  const slots = Array(23).fill(null);
  const preferred = new Set();
  for (const [slot, id] of preferences.entries()) {
   if (id && !assigned.has(id) && options[slot].some(p => p.id === id)) {
    assigned.set(id, slot);
    slots[slot] = id;
    preferred.add(slot);
   }
  }

  // Fill by rank before moving anyone. Only reassign a player to fill an
  // otherwise vacant slot, keeping any valid manual preference fixed.
  function place(slot, seen) {
   const free = options[slot].find(p => !seen.has(p.id) && !assigned.has(p.id));
   if (free) {
    assigned.set(free.id, slot);
    slots[slot] = free.id;
    return true;
   }
   for (const player of options[slot]) {
    const prior = assigned.get(player.id);
    if (seen.has(player.id) || preferred.has(prior)) continue;
    seen.add(player.id);
    if (place(prior, seen)) {
     assigned.set(player.id, slot);
     slots[slot] = player.id;
     return true;
    }
   }
   return false;
  }
  for (let slot = 0; slot < slots.length; slot++) {
   if (slots[slot] === null) place(slot, new Set());
  }
  return { lineup: slots.slice(0, 15), reserves: slots.slice(15), complete: slots.every(Boolean) };
 }

 function selectCallups({ players, nation, date, size = 30, isEligible, unavailableIds = [] }) {
  if (!validNation(nation) || !validDate(date) || !Number.isInteger(size) || size < 23 || size > 33) {
   throw Error('Convocation internationale invalide.');
  }
  const blocked = new Set(unavailableIds);
  const available = players.filter(p => !blocked.has(p.id) && fit(p) && (
   p.nationalReserve ? p.nation === nation : isEligible(p, nation, date)
  )).sort(byForm);
  const ids = available.map(p => p.id);
  if (!unique(ids) || !ids.every(validId)) throw Error('Identités de sélection invalides.');
  const sheet = selectInternationalSheet({ players: available, calledIds: ids });
  return [...new Set([...sheet.lineup, ...sheet.reserves].filter(Boolean).concat(ids))].slice(0, size);
 }

 function nationalReservePool(nation, strength = 70, size = 33) {
  if (!validNation(nation) || !Number.isFinite(strength) || !Number.isInteger(size) || size < 23 || size > 33) {
   throw Error('Vivier international fictif invalide.');
  }
  const origin = [...nation].reduce((value, letter) => value * 31 + letter.charCodeAt(0), 0);
  const roster = [...positions.keys(), ...cover, ...cover, 9, 11];
  return roster.slice(0, size).map((slot, i) => {
   const number = String(i + 1).padStart(2, '0');
   return {
    id: `national-${nation}-${number}`, name: `Joueur fictif ${nation} ${number}`, nation, nationalReserve: true,
    fam: families[slot], pos: positions[slot], age: 22 + (origin + i * 11) % 12,
    rating: Math.max(20, Math.min(97, Math.round(strength) - 5 + (origin + i * 7) % 11)),
    condition: 100, injury: 0,
   };
  });
 }

 function shiftDate(date, days) {
  return new Date(Date.parse(date) + days * day).toISOString().slice(0, 10);
 }

 function releasePeriods(fixtures, { worldCup = false, openingDate } = {}) {
  const dates = [...new Set(fixtures.map(f => f.date))].sort();
  if (!dates.every(validDate) || (worldCup && (!validDate(openingDate) || openingDate > dates[0]))) {
   throw Error('Calendrier de mise à disposition invalide.');
  }
  if (!dates.length) return [];
  if (worldCup) return [{ from: shiftDate(openingDate, -36), through: shiftDate(dates.at(-1), 1) }];
  const matchWeek = date => {
   const weekday = new Date(date).getUTCDay();
   return shiftDate(date, -((weekday + 6) % 7));
  };
  const periods = [];
  let last = null;
  for (const date of dates) {
   if (!last || matchWeek(date) > shiftDate(matchWeek(last), 7)) {
    periods.push({ from: shiftDate(date, -6), through: shiftDate(date, 1) });
   } else {
    periods.at(-1).through = shiftDate(date, 1);
   }
   last = date;
  }
  return periods;
 }

 function clubReleaseOn(callups, playerId, date) {
  return callups.find(callup => callup.from <= date && date <= callup.through && callup.playerIds.includes(playerId)) ?? null;
 }

 function validAppearance(row) {
  return row && Object.keys(row).length === 4 && validId(row.fixtureId) && validDate(row.date) && validNation(row.nation) &&
   Array.isArray(row.playedIds) && row.playedIds.length >= 15 && row.playedIds.length <= 23 &&
   row.playedIds.every(validId) && unique(row.playedIds);
 }

 function validateInternationalAppearances(appearances) {
  if (!Array.isArray(appearances)) return false;
  const sides = new Set();
  const played = new Set();
  for (const row of appearances) {
   if (!validAppearance(row)) return false;
   const side = `${row.fixtureId}/${row.nation}`;
   if (sides.has(side)) return false;
   sides.add(side);
   for (const id of row.playedIds) {
    const appearance = `${row.date}/${id}`;
    if (played.has(appearance)) return false;
    played.add(appearance);
   }
  }
  return true;
 }

 function recordInternationalAppearances(appearances, { fixtureId, date, nation, lineup, reserves, playedIds, completed }) {
  if (completed !== true) return false;
  const row = { fixtureId, date, nation, playedIds };
  if (!validAppearance(row) || !Array.isArray(lineup) || lineup.length !== 15 || !Array.isArray(reserves) || reserves.length > 8) {
   throw Error('Participation internationale invalide.');
  }
  const sheet = [...lineup, ...reserves];
  if (!unique(sheet) || !sheet.every(validId) || !lineup.every(id => playedIds.includes(id)) || !playedIds.every(id => sheet.includes(id))) {
   throw Error('Participation internationale incompatible avec la feuille.');
  }
  const prior = appearances.find(item => item.fixtureId === fixtureId && item.nation === nation);
  if (prior) {
   if (prior.date !== date || prior.playedIds.length !== playedIds.length || !playedIds.every(id => prior.playedIds.includes(id))) {
    throw Error('Participation internationale déjà enregistrée avec une autre feuille.');
   }
   return false;
  }
  if (appearances.some(item => item.date === date && playedIds.some(id => item.playedIds.includes(id)))) {
   throw Error('Deux participations internationales pour un même joueur le même jour.');
  }
  appearances.push({ ...row, playedIds: playedIds.slice() });
  return true;
 }

 function internationalCaps(appearances, playerId, baseline) {
  let career = 0;
  let latest = null;
  for (const row of appearances) {
   if (!row.playedIds.includes(playerId)) continue;
   career++;
   if (!latest || row.date > latest.date) latest = row;
  }
  const initial = baseline?.seniorCaps;
  return {
   career,
   total: (Number.isInteger(initial) && initial >= 0 ? initial : 0) + career,
   nation: latest?.nation ?? baseline?.seniorNation ?? null,
  };
 }

 function capBucket(id) {
  let bucket = 0;
  for (let i = 0; i < id.length; i++) bucket = (Math.imul(bucket, 31) + id.charCodeAt(i)) & 63;
  return String(bucket);
 }

 function internationalStatus(career) {
  const caps = new Map(), released = new Set();
  for (const [nation, buckets] of Object.entries(career.archivedCaps ?? {})) {
   for (const bucket of Object.values(buckets)) for (const [id, count] of Object.entries(bucket)) {
    caps.set(id, { career: count, nation });
   }
  }
  for (const row of career.appearances) for (const id of row.playedIds) {
   caps.set(id, { career: (caps.get(id)?.career ?? 0) + 1, nation: row.nation });
  }
  for (const camp of career.callups) {
   if (camp.from <= career.date && career.date <= camp.through) for (const id of camp.playerIds) released.add(id);
  }
  return { caps, released };
 }

 return Object.freeze({
  selectCallups, selectInternationalSheet, selectInternationalChoices, nationalReservePool, releasePeriods, clubReleaseOn,
  recordInternationalAppearances, validateInternationalAppearances, internationalCaps, capBucket, internationalStatus,
 });
}

module.exports = { ...factory(), factory };
