'use strict';
const assert = require('node:assert/strict');
const {test} = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createBridge} = require('../native/engine/worker.cjs');
const {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const {skipMatchTalk} = require('./helpers/scene-match-talks.cjs');
const {advanceToNextMatch} = require('./helpers/monde-matchs.cjs');

function profile(t, dailyCalendar = true) {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-management-day-'));
  const options = {dataDir, seed: 327, now: 1794178800000, dailyCalendar};
  let bridge = createBridge(options);
  let id = 0;
  t.after(() => {
    bridge.close();
    fs.rmSync(dataDir, {recursive: true, force: true});
  });
  const request = (command, payload = {}) => bridge.handle({id: ++id, command, payload});
  function good(command, payload) {
    const answer = request(command, payload);
    assert.equal(answer.ok, true, answer.error);
    return answer.model;
  }
  return {
    request, good,
    settle(model) { return settleClubMeetings(model, good); },
    advance(model) {
      const ready = settleClubMeetings(model, good);
      return good('advance_day', {fromDate: ready.meta.calendarToday});
    },
    disk() {
      return JSON.parse(fs.readFileSync(path.join(dataDir, 'PrototypeGodot', 'donnees.json'), 'utf8'));
    },
    restart(override = {}) {
      bridge.close();
      bridge = createBridge({...options, ...override});
      return good('snapshot');
    },
  };
}

test('le pas journalier conserve le calendrier, la semaine et le RNG entre deux jours', t => {
  const game = profile(t);
  const start = game.settle(game.good('new_career', {mode: 'world-champ', club: 102}));
  assert.deepEqual(start.meta.calendarCadence, {day: 0, matchReady: false, canAdvance: true, preseason: true});
  assert.equal(start.meta.calendarToday, '2026-07-13');
  assert.equal(start.calendarPlanning.today, start.meta.calendarToday);
  assert.equal(start.next, null);
  const opening = game.disk();
  assert.equal(game.request('begin_match').ok, false);
  assert.equal(game.request('finish_round').ok, false);
  const after = game.advance(start);
  assert.equal(after.meta.calendarToday, '2026-07-14');
  assert.equal(after.calendarPlanning.today, after.meta.calendarToday);
  assert.equal(after.meta.week, start.meta.week);
  assert.equal(after.finance.cash, start.finance.cash);
  assert.equal(after.meta.trained, start.meta.trained);
  assert.equal(game.disk().seed, opening.seed);
  assert.deepEqual(after.calendar, start.calendar);
  assert.equal(game.request('advance_day', {fromDate: start.meta.calendarToday}).ok, false);
  assert.equal(game.request('advance_day').ok, false);
  assert.equal(game.restart().meta.calendarToday, after.meta.calendarToday);
  let next = after;
  while (next.meta.week === start.meta.week) next = game.advance(next);
  assert.equal(next.meta.calendarToday, '2026-08-24', 'la semaine 0 couvre toute l’avant-saison');
  assert.equal(next.meta.calendarCadence.day, 0);
});

test('le jour du match bloque le calendrier et le résultat confirmé reste disponible le lendemain', t => {
  const game = profile(t);
  let model = game.settle(game.good('new_career', {mode: 'world-champ', club: 92}));
  const first = model.calendar[0];
  assert.deepEqual(
    [first.date, first.kickoffLocal, first.home.id, first.away.id],
    ['2026-08-21', '19:30', 92, 100]
  );
  while (model.meta.calendarToday < first.date) model = game.advance(model);
  assert.equal(model.next.date, first.date);
  assert.equal(model.next.kickoffLocal, first.kickoffLocal);
  assert.equal(model.meta.calendarCadence.matchReady, true);
  assert.equal(model.meta.calendarCadence.canAdvance, false);
  assert.equal(game.request('advance_day', {fromDate: first.date}).ok, false);
  const begun = game.good('begin_match');
  assert.equal(begun.clubLife.matchTalks.scene.phase, 'pre');
  skipMatchTalk(begun, game.good);
  assert.equal(game.request('advance_day', {fromDate: first.date}).ok, false);
  const played = game.good('delegate');
  const before = game.disk();
  model = game.good('finish_round');
  assert.equal(model.meta.calendarToday, first.date);
  assert.equal(model.meta.calendarCadence.resultConfirmed, true);
  assert.equal(model.meta.calendarCadence.canAdvance, true);
  assert.equal(model.live, null);
  assert.equal(model.next, null);
  assert.equal(model.calendar[0].played, true);
  assert.deepEqual(model.calendar[0].score, played.live.score);
  assert.equal(game.disk().seed, before.seed);
  const confirmed = JSON.parse(game.good('export').meta.exportText).state;
  assert.equal(confirmed.live.finished, true, 'The shared confirmation preserves live evidence until the weekly close');
  assert.deepEqual(confirmed.live.score, played.live.score);
  assert.equal(confirmed.trained, true);
  assert.equal(game.request('finish_round').ok, false);
  assert.equal(game.restart().meta.calendarCadence.resultConfirmed, true);
  model = game.advance(model);
  assert.equal(model.meta.calendarToday, '2026-08-22');
  assert.equal(model.meta.calendarCadence.resultConfirmed, true);
  assert.deepEqual(game.restart().calendar[0].score, played.live.score);
  while (model.meta.calendarCadence.resultConfirmed) model = game.advance(model);
  assert.equal(model.meta.calendarToday, '2026-08-24');
  const saved = JSON.parse(game.good('export').meta.exportText).state;
  assert.equal(saved.live, null);
  assert.equal(saved.trained, false);
  assert.equal(saved.history.filter(row => row.fixtureId === first.id).length, 1);
  assert.deepEqual(saved.history.find(row => row.fixtureId === first.id).score, played.live.score);
});

test('la reprise d’une ancienne sauvegarde garde son calendrier et sa date de match', t => {
  const game = profile(t, false);
  // Cadence hebdomadaire (sans calendrier journalier) : la carrière avance jusqu'au premier match du club.
  const legacy = advanceToNextMatch(game.settle(game.good('new_career', {mode: 'world-champ', club: 0})), game.good);
  assert.equal(legacy.meta.calendarCadence, undefined);
  const stored = game.disk();
  const upgraded = game.restart({dailyCalendar: true});
  assert.equal(upgraded.meta.calendarToday, legacy.meta.calendarToday);
  assert.deepEqual(upgraded.calendar, legacy.calendar);
  assert.equal(upgraded.meta.calendarCadence.canAdvance, true);
  assert.deepEqual(game.disk(), stored);
  game.restart();
  const live = game.good('begin_match');
  assert.equal(live.live.finished, false);
  const liveExport = game.good('export').meta.exportText;
  const resumed = game.restart({dailyCalendar: true});
  assert.equal(resumed.meta.calendarToday, legacy.next.date);
  assert.equal(resumed.meta.calendarCadence.canAdvance, false);
  assert.equal(resumed.live.paused, true);
  const imported = game.good('import', {text: liveExport});
  assert.equal(imported.meta.calendarToday, legacy.next.date);
  assert.deepEqual(imported.calendar, upgraded.calendar);
});
test('l’édition Monde charge les 422 affiches LNR de 2026–27 sans collision', async t => {
  for (const mode of ['world-champ']) {
    await t.test(mode, t => {
      // Each edition is an independent import round trip. Keep its durable
      // checkpoints and profile lifetime independent from the other editions.
      const game = profile(t);
      const model = game.good('new_career', {mode, club: 26});
      assert.equal(model.meta.calendarToday, '2026-07-13', mode);
      const first = model.calendar[0];
      assert.deepEqual(
        [first.date, first.kickoffLocal, first.kickoffSource, first.home.id, first.away.id],
        ['2026-08-27', '19:30', 'published', 26, 22], mode
      );
      assert.deepEqual(first.dateWindow, ['2026-08-27', '2026-08-28'], mode);
      const doc = JSON.parse(game.good('export').meta.exportText);
      const fixtures = doc.state.worldMode.fixtures;
      const league = id => fixtures.filter(f => f.competitionId === id);
      assert.equal(league('elite').length, 182);
      assert.equal(league('accession').length, 240);
      assert.equal(league('elite').at(-1).date, '2027-06-06');
      assert.equal(league('accession').at(-1).date, '2027-05-14');
      assert.equal(league('elite').filter(f => f.kickoffSource === 'published').length, 77);
      assert.equal(league('accession').filter(f => f.kickoffSource === 'published').length, 112);
      const briveGrenoble = league('accession').find(f => f.sourceFixtureId === 12057);
      assert.equal(briveGrenoble.date, '2026-10-17');
      assert.deepEqual(briveGrenoble.dateWindow, ['2026-10-17', '2026-10-17']);
      assert.match(first.sourceRef, /lnr\.fr\/feuille-de-match\//);
      const occupied = fixtures.flatMap(f => [f.homeId, f.awayId].map(id => f.week + ':' + id));
      assert.equal(new Set(occupied).size, occupied.length, mode);
      assert.deepEqual(game.good('import', {text: JSON.stringify(doc)}).calendar, model.calendar);
    });
  }
});

test('les heures publiées du Pacifique restent locales et les autres créneaux sont signalés', t => {
  const game = profile(t);
  const pacific = game.good('new_career', {mode: 'world-champ', club: 61});
  const first = pacific.calendar.find(f => f.date === '2027-02-12');
  assert.equal(first.kickoffUtc, '2027-02-12T06:35:00Z');
  assert.equal(first.kickoffLocal, '19:35');
  assert.equal(first.timezone, 'Pacific/Auckland');
  assert.equal(first.kickoffSource, 'published');
  const prem = game.good('new_career', {mode: 'world-champ', club: 30});
  assert.equal(prem.calendar[0].date, '2026-09-25');
  assert.equal(prem.calendar[0].kickoffSource, 'simulated-not-official');
  assert.match(prem.calendar[0].kickoffLocal, /^\d{2}:\d{2}$/);
});
