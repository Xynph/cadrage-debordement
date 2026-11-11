'use strict';

// This factory also runs inside the native game VM. France30 and the Base
// commune keep their existing weekly competition and financial cycle.
module.exports = function makeFranceCalendarCadence(userFixture) {
  const DAY_MS = 86400000;
  const MATCH_DAY = 5;
  const LAST_DAY = 6;
  const available = state => state?.worldMode === undefined && state?.franceMode?.version === 1
    && state.franceMode.catalogue === 'france-territories-2026-10-31-v1';

  function date(season, week, day = MATCH_DAY) {
    const year = 2025 + season;
    if (!Number.isSafeInteger(season) || season < 1 || year > 9998
      || !Number.isSafeInteger(week) || week < 0 || week > 34
      || !Number.isSafeInteger(day) || day < 0 || day > LAST_DAY) return null;
    const firstSeptember = Date.UTC(year, 8, 1);
    const weekday = new Date(firstSeptember).getUTCDay();
    const firstMonday = (8 - weekday) % 7;
    return new Date(firstSeptember + (firstMonday + week * 7 + day) * DAY_MS).toISOString().slice(0, 10);
  }

  function project(state, enabled = false) {
    if (!available(state) || (!enabled && state.franceCalendar === undefined)) return null;
    const day = state.franceCalendar?.day ?? (state.live ? MATCH_DAY : 0);
    const calendarToday = date(state.season, state.franceMode.week, day);
    if (!calendarToday) return null;
    const resultConfirmed = state.franceCalendar?.resultConfirmed === true;
    const open = state.phase !== 'ended';
    const matchReady = open && day === MATCH_DAY && !resultConfirmed && !!userFixture(state);
    const canAdvance = open && !matchReady && (!state.live || resultConfirmed);
    return {
      calendarToday,
      calendarCadence: {day, matchReady, canAdvance, ...(resultConfirmed ? {resultConfirmed} : {})},
    };
  }

  function validate(state) {
    const value = state?.franceCalendar;
    if (value === undefined) return;
    const invalid = () => { throw Error('Calendrier simulé France30 incohérent.'); };
    if (!available(state) || !value || typeof value !== 'object' || Array.isArray(value)
      || !Number.isSafeInteger(value.day) || Object.keys(value).some(k => k !== 'day' && k !== 'resultConfirmed')
      || !date(state.season, state.franceMode.week, value.day)
      || (Object.hasOwn(value, 'resultConfirmed') && value.resultConfirmed !== true)) invalid();

    const {day, resultConfirmed} = value;
    if (state.phase === 'ended') {
      if (day !== 0 || state.live || resultConfirmed) invalid();
      return;
    }
    const fixture = userFixture(state);
    if (resultConfirmed && (!fixture || state.live?.finished !== true || day < MATCH_DAY)) invalid();
    if (state.live && (!fixture || (!resultConfirmed && day !== MATCH_DAY))) invalid();
    if (fixture && day > MATCH_DAY && !resultConfirmed) invalid();
  }

  function advance(state, fromDate) {
    const current = project(state, true);
    if (!current || state.phase === 'ended') throw Error('Pas journalier indisponible.');
    if (fromDate !== current.calendarToday) throw Error('La date de carrière a changé.');
    const {day, canAdvance, resultConfirmed} = current.calendarCadence;
    if (!canAdvance) throw Error('Jouez la rencontre et confirmez son résultat avant de continuer.');
    if (day === LAST_DAY) return {closeWeek: true, calendar: {day: 0}};
    return {closeWeek: false, calendar: {day: day + 1, ...(resultConfirmed ? {resultConfirmed} : {})}};
  }

  function confirm(state) {
    const current = project(state, true);
    if (!current || state.phase === 'ended') throw Error('Confirmation de résultat indisponible.');
    if (current.calendarCadence.resultConfirmed) throw Error('Le résultat a déjà été confirmé.');
    if (!current.calendarCadence.matchReady || state.live?.finished !== true) {
      throw Error('Le match doit être terminé pour confirmer le résultat.');
    }
    return {day: current.calendarCadence.day, resultConfirmed: true};
  }

  return Object.freeze({date, project, validate, advance, confirm});
};
