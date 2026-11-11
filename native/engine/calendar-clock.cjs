'use strict';

const DAY = 86400000;

function dated(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const time = Date.parse(value + 'T00:00:00Z');
  return Number.isFinite(time) && new Date(time).toISOString().slice(0,10) === value;
}

function shift(date, days) {
  return new Date(Date.parse(date + 'T00:00:00Z') + days * DAY).toISOString().slice(0,10);
}

function monday(date) {
  const weekday = new Date(date + 'T00:00:00Z').getUTCDay();
  return shift(date, -((weekday + 6) % 7));
}

function weekIndex(fixture) {
  return Number.isSafeInteger(fixture.week) && fixture.week >= 0 ? fixture.week : null;
}

function calendarContext(model) {
  const meta = model.meta || {};
  const fixtures = model.calendar || [];
  const week = weekIndex(meta);
  const season = meta.season;
  if (!model.club || week === null || !Number.isSafeInteger(season) || season < 1) {
    return {fixtures, today:null, simulatedDates:false};
  }

  if (meta.mode === 'world') {
    if (dated(meta.calendarToday)) {
      return {fixtures,today:model.live && dated(meta.date) ? meta.date : meta.calendarToday,simulatedDates:false};
    }
    const anchors = fixtures.filter(fixture => dated(fixture.date) && weekIndex(fixture) !== null);
    anchors.sort((a,b) => Math.abs(a.week-week)-Math.abs(b.week-week) || a.date.localeCompare(b.date));
    const anchor = anchors[0];
    const today = model.live && dated(meta.date) ? meta.date :
      anchor ? shift(monday(anchor.date),7*(week-anchor.week)) :
      dated(meta.date) ? monday(meta.date) : null;
    return {fixtures,today,simulatedDates:false};
  }

  // The legacy calendars express only a fictional weekly cadence. This date is
  // for planning and never replaces a competition date in the career model.
  const year = 2025 + season;
  if (year > 9998) return {fixtures,today:null,simulatedDates:false};
  const firstSeptember = `${year}-09-01`;
  const openingMonday = monday(firstSeptember);
  const start = openingMonday < firstSeptember ? shift(openingMonday,7) : openingMonday;
  const firstSaturday = shift(start,5);
  const simulated = fixtures.map(fixture => {
    if (dated(fixture.date) || weekIndex(fixture) === null) return fixture;
    const key = [season,fixture.week,fixture.phase,fixture.home?.id,fixture.away?.id].join(':');
    return {...fixture,id:'weekly:'+key,date:shift(firstSaturday,7*fixture.week),dateSimulated:true,
      ...(dated(meta.calendarToday) ? {kickoffLocal:'15:00',kickoffSource:'simulated-not-official',timezone:'Europe/Paris'} : {})};
  });
  return {
    fixtures:simulated,
    today:dated(meta.calendarToday)?meta.calendarToday:shift(start,week*7+(model.live ? 5 : 0)),
    simulatedDates:true
  };
}

module.exports = {calendarContext};
