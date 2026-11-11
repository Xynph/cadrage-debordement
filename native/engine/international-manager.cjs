'use strict';

function factory() {
 const modes = ['club', 'nation', 'dual'];
 const historyLimit = 40;
 const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
  Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
 const validNation = value => typeof value === 'string' && /^[A-Z]{3}$/.test(value);
 const sameRole = (a, b) => a.club === b.club && a.nation === b.nation;
 const record = (value, length) => value && typeof value === 'object' && !Array.isArray(value) &&
  Object.keys(value).length === length;

 function managerRole(role) {
  const club = role?.club ?? true;
  const nation = role?.nation ?? null;
  return { mode: nation ? (club ? 'dual' : 'nation') : 'club', club, nation };
 }

 function selectionFor(mode, nation, supportedNations) {
  if (!modes.includes(mode)) throw Error('Rôle de manager invalide.');
  if (mode === 'club') {
   if (nation !== undefined && nation !== null) throw Error('Le mandat en club ne comporte pas de sélection.');
   return { club: true, nation: null };
  }
  if (!validNation(nation) || !new Set(supportedNations).has(nation)) throw Error('Sélection nationale indisponible.');
  return { club: mode === 'dual', nation };
 }

 function createManagerRole({ mode = 'club', nation, date }, supportedNations) {
  if (!validDate(date)) throw Error('Date du mandat invalide.');
  return { version: 1, ...selectionFor(mode, nation, supportedNations), since: date, history: [] };
 }

 function nationalOffers(role, supportedNations) {
  const { nation } = managerRole(role);
  return [...new Set(supportedNations)].filter(candidate => validNation(candidate) && candidate !== nation).sort();
 }

 function validateManagerRole(role, { supportedNations, date } = {}) {
  if (role === undefined) return true;
  const supported = new Set(supportedNations);
  const validTenure = entry => typeof entry.club === 'boolean' && validDate(entry.since) &&
   (entry.nation === null ? entry.club : validNation(entry.nation) && supported.has(entry.nation));
  if (!record(role, 5) || role.version !== 1 || !validTenure(role) ||
   (date !== undefined && (!validDate(date) || role.since > date)) ||
   !Array.isArray(role.history) || role.history.length > historyLimit) return false;
  let previous = null;
  for (const tenure of role.history) {
   if (!record(tenure, 3) || !validTenure(tenure) || tenure.since > role.since ||
    (previous && (previous.since > tenure.since || sameRole(previous, tenure)))) return false;
   previous = tenure;
  }
  return !previous || !sameRole(previous, role);
 }

 function applyManagerRole(role, request, context) {
  const { supportedNations, date, nationalOffer, clubOffer, activeClubId, matchInProgress } = context;
  if (matchInProgress) throw Error('Changement de mandat indisponible pendant un match.');
  if (!validDate(date) || date !== request.date || !validateManagerRole(role, { supportedNations, date })) {
   throw Error('Le contexte de carrière a changé.');
  }
  const before = managerRole(role);
  if (request.fromMode !== before.mode || request.fromNation !== before.nation) throw Error('Le mandat actuel a changé.');
  const after = selectionFor(request.mode, request.nation, supportedNations);
  if (sameRole(before, after)) throw Error('Ce mandat est déjà actif.');
  if (after.nation !== null && after.nation !== before.nation && nationalOffer !== after.nation) {
   throw Error('Une offre de la sélection est nécessaire.');
  }
  if (!before.club && after.club && (clubOffer?.status !== 'completed' || !Number.isInteger(activeClubId) ||
   activeClubId < 0 || clubOffer.clubId !== activeClubId)) {
   throw Error('Une prise de poste effective en club est nécessaire.');
  }
  const history = role ? [...role.history, { club: role.club, nation: role.nation, since: role.since }].slice(-historyLimit) : [];
  return { version: 1, ...after, since: date, history };
 }

 return Object.freeze({ createManagerRole, managerRole, nationalOffers, applyManagerRole, validateManagerRole });
}

module.exports = { ...factory(), factory };
