'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const competitions = require('../native/engine/international-competitions.cjs');
const callups = require('../native/engine/international-callups.cjs');
const extra = require('../native/engine/international-tests.cjs');
const { createInternationalCareer } = require('../native/engine/international-career.cjs');

const yearEditions = year => [...competitions.editionIds(year, year), ...competitions.extraEditionIds(year, year)]
  .map(id => competitions.createEdition(id));
const sixNations = ['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL'];
const sanzaar = ['NZL', 'RSA', 'AUS', 'ARG'];

test('chaque sélection joue à peu près le même nombre de matchs chaque année, sur trente ans', () => {
  for (let year = 2027; year <= 2056; year++) {
    const counts = extra.expectedCounts(yearEditions(year));
    assert.equal(counts.size, 24, String(year));
    for (const [nation, count] of counts) {
      assert.ok(count >= 8 && count <= 13, year + ' ' + nation + ' ' + count);
    }
    const values = [...counts.values()];
    assert.ok(values.reduce((a, b) => a + b, 0) / values.length >= 11, String(year));
  }
});

test('les tests complémentaires respectent les saisons et ne chevauchent aucune autre fenêtre', () => {
  for (let year = 2026; year <= 2045; year++) {
    const editions = yearEditions(year);
    const tests = editions.find(edition => edition.id === 'test-matches-' + year);
    assert.deepEqual(tests, competitions.createEdition('test-matches-' + year), 'reproductible');
    for (const fixture of tests.fixtures) {
      assert.equal(fixture.phase, 'test');
      const month = Number(fixture.date.slice(5, 7));
      const teams = [fixture.homeId, fixture.awayId];
      if (month <= 3) assert.ok(teams.every(id => !sixNations.includes(id) && !sanzaar.includes(id)), fixture.id);
      if (fixture.window !== 'warmup') {
        assert.ok(!teams.every(id => sixNations.includes(id)), fixture.id);
        assert.ok(!teams.every(id => sanzaar.includes(id)), fixture.id);
      }
      if (fixture.window === 'november' && teams.some(id => sixNations.includes(id)) && teams.some(id => !sixNations.includes(id))) {
        assert.ok(sixNations.includes(fixture.homeId) || ['GEO', 'ESP', 'POR', 'ROU'].includes(fixture.homeId), fixture.id);
      }
      if (year > 2026 && (year - 2027) % 4 !== 0 && [8, 9].includes(month)) assert.ok(teams.every(id => !sixNations.includes(id)), fixture.id);
    }
    // Une nation n'est jamais convoquée pour deux compétitions à la fois.
    const periods = new Map();
    for (const edition of editions) {
      const cup = edition.id.startsWith('rugby-world-cup-');
      for (const { id } of edition.teams) {
        const own = edition.fixtures.filter(f => f.homeId === id || f.awayId === id || !f.homeId);
        if (!own.length) continue;
        const list = cup ? callups.releasePeriods(own, { worldCup: true, openingDate: edition.fixtures[0].date })
          : callups.releasePeriods(own);
        for (const period of list) {
          const key = id === extra.LIONS ? null : id;
          if (!key) continue;
          if (!periods.has(key)) periods.set(key, []);
          periods.get(key).push({ ...period, edition: edition.id });
        }
      }
    }
    for (const [nation, list] of periods) for (const a of list) for (const b of list) {
      if (a.edition === b.edition || a.edition.startsWith('rugby-world-cup-') || b.edition.startsWith('rugby-world-cup-')) continue;
      assert.ok(a.through < b.from || b.through < a.from, year + ' ' + nation + ' ' + a.edition + ' / ' + b.edition);
    }
  }
});

test('les vraies compétitions gardent leurs équipes, leurs hôtes et leur rotation', () => {
  const pnc = competitions.createEdition('pacific-nations-cup-2026');
  assert.deepEqual(pnc.fixtures.filter(f => f.phase === 'semi-final').map(f => [f.date, f.homeId, f.awayId]),
    [['2026-09-12', 'FIJ', 'CAN'], ['2026-09-12', 'JPN', 'USA']]);
  assert.equal(pnc.fixtures.find(f => f.phase === 'final').date, '2026-09-19');
  const cup = competitions.createEdition('nations-cup-2026');
  assert.equal(cup.fixtures.length, 30);
  assert.deepEqual(cup.teams.map(t => t.id).sort(), ['CAN', 'CHI', 'ESP', 'GEO', 'HKG', 'POR', 'ROU', 'SAM', 'TGA', 'URU', 'USA', 'ZIM']);
  assert.throws(() => competitions.createEdition('nations-cup-2027'), /unknown/);
  assert.deepEqual([2029, 2033, 2037, 2041].map(year => competitions.createEdition('lions-tour-' + year).fixtures[0].homeId),
    ['NZL', 'RSA', 'AUS', 'NZL']);
  assert.ok(competitions.createEdition('lions-tour-2029').fixtures.every(f => f.awayId === 'BIL' && f.date.startsWith('2029-07-')));
  assert.equal(competitions.createEdition('greatest-rivalry-2026').fixtures[0].homeId, 'NZL');
  assert.equal(competitions.createEdition('greatest-rivalry-2030').fixtures[0].homeId, 'RSA');
  assert.throws(() => competitions.createEdition('greatest-rivalry-2028'), /unknown/);
  assert.equal(competitions.familyName('rugby-europe-championship-2031'), 'Rugby Europe Championship 2031');
  assert.equal(competitions.familyName('six-nations-2031'), 'Tournoi des Six Nations 2031');
});

test('phases finales résolues, séries et tests nuls jouables jusqu’au palmarès', () => {
  for (const id of ['pacific-nations-cup-2026', 'pacific-nations-cup-2029', 'rugby-europe-championship-2029', 'nations-cup-2028',
    'lions-tour-2029', 'greatest-rivalry-2030', 'test-matches-2029']) {
    let edition = competitions.createEdition(id);
    for (let guard = 0; edition.fixtures.some(f => !f.result) && guard < 200; guard++) {
      const next = edition.fixtures.find(f => !f.result && f.homeId && f.awayId);
      assert.ok(next, id + ' bloquée');
      edition = competitions.recordResult(edition, next.id, competitions.simulateResult(edition, next.id, { seed: 5 }));
    }
    const outcome = competitions.editionOutcome(edition);
    assert.equal(outcome.complete, true, id);
    if (id.startsWith('test-matches')) assert.deepEqual(competitions.standings(edition), []);
    else if (!id.startsWith('lions') && !id.startsWith('greatest')) assert.ok(outcome.winnerIds.length >= 1, id);
    if (id === 'nations-cup-2028') assert.equal(outcome.winnerIds.length, 2);
    const results = Object.fromEntries(edition.fixtures.map(f => [f.id, f.result]));
    assert.deepEqual(competitions.restoreEdition(id, results), edition);
  }
  const tests = competitions.createEdition('test-matches-2029');
  const fixture = tests.fixtures[0];
  const draw = competitions.recordResult(tests, fixture.id, { home: 13, away: 13, homeTries: 1, awayTries: 1 });
  assert.equal(draw.fixtures[0].result.winnerId, null);
});

test('les Lions convoquent des joueurs des quatre nations britanniques sans les attacher à une sélection', () => {
  const facts = { players: {} };
  const players = [];
  const positions = [[0, 'Pilier gauche'], [1, 'Talonneur'], [0, 'Pilier droit'], [2, 'Deuxième ligne'], [2, 'Deuxième ligne'],
    [3, 'Troisième ligne'], [3, 'Troisième ligne'], [3, 'Numéro 8'], [4, 'Demi de mêlée'], [5, 'Demi d’ouverture'],
    [6, 'Ailier'], [7, 'Centre'], [7, 'Centre'], [6, 'Ailier'], [8, 'Arrière']];
  for (const nation of ['ENG', 'IRE']) positions.forEach(([fam, pos], i) => {
    const id = 'lnr:' + nation.toLowerCase() + '-' + i;
    facts.players[id] = { seniorNation: nation };
    players.push({ id, pos, fam, rating: 99, age: 27, condition: 100 });
  });
  const game = createInternationalCareer(competitions, callups, facts);
  const start = game.initial('2029-06-01', 3);
  assert.equal(start.version, 3);
  const end = game.advance(start, { from: start.date, to: '2029-08-01', players }).state;
  const camp = end.callups.find(row => row.nation === 'BIL');
  assert.ok(camp.playerIds.filter(id => id.startsWith('lnr:')).length >= 25);
  const lionsRows = end.appearances.filter(row => row.nation === 'BIL');
  assert.equal(lionsRows.length, 3);
  assert.equal(game.validate(JSON.parse(JSON.stringify(end))), true);
  const status = callups.internationalStatus(end);
  const englishLion = lionsRows[0].playedIds.find(id => id.startsWith('lnr:eng'));
  assert.ok(!status.caps.get(englishLion) || status.caps.get(englishLion).nation === 'ENG');
  // En novembre, les Anglais retrouvent l'Angleterre et les Irlandais l'Irlande.
  const autumn = game.advance(end, { from: end.date, to: '2029-12-01', players }).state;
  for (const row of autumn.appearances.filter(r => ['ENG', 'IRE'].includes(r.nation))) {
    assert.ok(row.playedIds.filter(id => id.startsWith('lnr:')).every(id => id.startsWith('lnr:' + row.nation.toLowerCase())));
  }
  assert.equal(game.validate(JSON.parse(JSON.stringify(autumn))), true);
});

test('une carrière de version 2 passe au calendrier complet sans sélection rétroactive', () => {
  const game = createInternationalCareer(competitions, callups, { players: {} });
  const current = game.initial('2028-01-10', 9);
  const legacy = JSON.parse(JSON.stringify(current));
  legacy.version = 2;
  delete legacy.extendedFrom;
  for (const [year, rows] of Object.entries(legacy.results)) {
    for (const id of Object.keys(rows)) if (competitions.EXTRA_FAMILIES.some(family => id.startsWith(family + '-'))) delete rows[id];
    if (!Object.keys(rows).length) delete legacy.results[year];
  }
  assert.equal(game.validate(legacy), true);
  const upgraded = game.upgrade(legacy);
  assert.equal(upgraded.version, 3);
  assert.equal(upgraded.extendedFrom, '2028-01-10');
  assert.equal(game.validate(JSON.parse(JSON.stringify(upgraded))), true);
  const later = game.advance(upgraded, { from: upgraded.date, to: '2028-03-31', players: [] }).state;
  assert.ok(Object.keys(later.results['2028']).some(id => id.startsWith('test-matches-2028-') ||
    id.startsWith('rugby-europe-championship-2028-')));
  assert.equal(game.validate(JSON.parse(JSON.stringify(later))), true);
});
