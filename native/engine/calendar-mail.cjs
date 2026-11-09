'use strict';

const MAX_FIXTURES = 128;
const MAX_MESSAGES = 256;
const MAX_TEXT_LENGTH = 240;
const STATUSES = new Set(['pending', 'recalibrated', 'kept', 'superseded', 'expired']);
const DECISIONS = new Map([['recalibrate', 'recalibrated'], ['keep', 'kept']]);

function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const instant = new Date(value + 'T00:00:00Z');
  return Number.isFinite(instant.getTime()) && instant.toISOString().slice(0, 10) === value;
}

function id(value) {
  return typeof value === 'string' && value.length > 0 && value.length <= 160 && !/[\u0000-\u001f\u007f]/.test(value);
}

function record(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function scope(value) {
  return record(value) && Number.isSafeInteger(value.clubId) && value.clubId >= 0
    && Number.isSafeInteger(value.season) && value.season > 0;
}

function validate(state) {
  if (state === undefined || state === null) return true;
  if (!record(state) || state.version !== 1 || !scope(state.scope)
    || !Number.isSafeInteger(state.sequence) || state.sequence < 0
    || !Array.isArray(state.fixtures) || state.fixtures.length > MAX_FIXTURES
    || !Array.isArray(state.messages) || state.messages.length > MAX_MESSAGES) return false;
  const fixtures = new Map();
  for (const fixture of state.fixtures) {
    if (!record(fixture) || !id(fixture.id) || fixtures.has(fixture.id)
      || !date(fixture.date) || !date(fixture.planDate)) return false;
    fixtures.set(fixture.id, fixture);
  }
  let previousSequence = 0;
  const pendingFixtures = new Set();
  for (const message of state.messages) {
    if (!record(message) || typeof message.id !== 'string') return false;
    const sequence = Number(/^calendar-date-(\d+)$/.exec(message.id)?.[1]);
    if (!Number.isSafeInteger(sequence) || sequence <= previousSequence || sequence > state.sequence
      || !id(message.fixtureId) || !date(message.fromDate) || !date(message.toDate)
      || message.fromDate === message.toDate || !date(message.planFromDate)
      || typeof message.opponent !== 'string' || message.opponent.length > MAX_TEXT_LENGTH
      || !STATUSES.has(message.status)) return false;
    previousSequence = sequence;
    if (message.status === 'pending') {
      const fixture = fixtures.get(message.fixtureId);
      if (pendingFixtures.has(message.fixtureId) || fixture?.date !== message.toDate
        || fixture.planDate !== message.planFromDate) return false;
      pendingFixtures.add(message.fixtureId);
    }
  }
  return true;
}

function datedFixtures(calendar) {
  const fixtures = new Map();
  for (const fixture of calendar) {
    if (!id(fixture?.id) || !date(fixture.date)) continue;
    if (fixtures.has(fixture.id)) throw Error('Identifiant de rencontre dupliqué dans le calendrier.');
    fixtures.set(fixture.id, fixture);
  }
  if (fixtures.size > MAX_FIXTURES) throw Error('Trop de rencontres pour le suivi du calendrier.');
  return fixtures;
}

function actionable(fixture, today) {
  return fixture && !fixture.played && fixture.date >= today;
}

function opponentName(fixture, clubId) {
  const opponent = fixture.home?.id === clubId ? fixture.away : fixture.home;
  return String(opponent?.presentation?.name ?? opponent?.name ?? '').slice(0, MAX_TEXT_LENGTH);
}

function observe(calendar, state, context) {
  if (!scope(context) || !date(context.today)) throw Error('Contexte du calendrier invalide.');
  if (!validate(state)) throw Error('Historique des dates de match invalide.');
  const current = datedFixtures(calendar);
  const sameSeason = state?.scope.clubId === context.clubId && state.scope.season === context.season;
  const previous = new Map(sameSeason ? state.fixtures.map(fixture => [fixture.id, fixture]) : []);
  const messages = (state?.messages ?? []).map(message => {
    if (message.status !== 'pending') return message;
    const next = sameSeason ? current.get(message.fixtureId) : null;
    if (!actionable(next, context.today)) return { ...message, status: 'expired' };
    if (next.date !== message.toDate) return { ...message, status: 'superseded' };
    return message;
  });
  let sequence = state?.sequence ?? 0;
  const fixtures = [];
  for (const [fixtureId, fixture] of current) {
    const prior = previous.get(fixtureId);
    const planDate = prior?.planDate ?? fixture.date;
    fixtures.push({ id: fixtureId, date: fixture.date, planDate });
    if (!prior || prior.date === fixture.date || !actionable(fixture, context.today)) continue;
    messages.push({
      id: 'calendar-date-' + ++sequence, fixtureId, fromDate: prior.date, toDate: fixture.date,
      planFromDate: planDate, opponent: opponentName(fixture, context.clubId), status: 'pending'
    });
  }
  const excess = Math.max(0, messages.length - MAX_MESSAGES);
  let removed = 0;
  const retained = messages.filter(message => {
    if (removed >= excess || message.status === 'pending') return true;
    removed += 1;
    return false;
  });
  return { version: 1, scope: { clubId: context.clubId, season: context.season }, sequence, fixtures, messages: retained };
}

function project(state) {
  return (state?.messages ?? []).map(message => ({ ...message }));
}

function anchors(state) {
  return (state?.fixtures ?? []).filter(fixture => fixture.planDate !== fixture.date)
    .map(fixture => ({ fixtureId: fixture.id, date: fixture.planDate }));
}

function decide(state, payload) {
  const status = DECISIONS.get(payload?.choice);
  if (!status || !id(payload?.id)) throw Error('Choix de préparation invalide.');
  if (!validate(state)) throw Error('Historique des dates de match invalide.');
  const message = state?.messages.find(item => item.id === payload.id);
  if (!message || message.status === 'superseded' || message.status === 'expired') {
    throw Error('Ce courrier de changement de date n’est plus disponible.');
  }
  if (message.status === status) return { state, change: null };
  if (message.status !== 'pending') throw Error('Une décision a déjà été enregistrée pour ce courrier.');
  const fixtures = status === 'recalibrated' ? state.fixtures.map(fixture => (
    fixture.id === message.fixtureId ? { ...fixture, planDate: message.toDate } : fixture
  )) : state.fixtures;
  const messages = state.messages.map(item => item === message ? { ...item, status } : item);
  const { fixtureId, planFromDate: fromDate, toDate } = message;
  const change = fromDate === toDate ? null : { fixtureId, fromDate, toDate };
  return { state: { ...state, fixtures, messages }, change };
}

module.exports = { observe, project, anchors, decide, validate };
