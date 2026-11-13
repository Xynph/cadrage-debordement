'use strict';
// Espoirs (18-21 ans) en feuille de match des clubs de l'ordinateur : environ 7 Espoirs
// différents par club et par saison (réel Top 14 2025-26, jusqu'à 11), davantage pendant
// les fenêtres internationales et dans les matchs à faible enjeu, sans dégrader le JIFF.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { context } = require('./france-harness.cjs');
const worldVm = require('../native/engine/world-vm.cjs');
const registry = require('../native/engine/world-registry.json');
const jiff = require('../native/engine/jiff.cjs');
const espoirs = require('../native/engine/espoirs-match.cjs');

// Centres bien fournis comme dans la carrière native (la base de test n'en a que 4 ou 5 par club).
const FILL = `for(const a of S.aiRoster.academies){const c=S.clubs[a.clubId];
  for(let k=0;k<40;k++){const p=academyPlayer(c.id,k%15,S.season,100+k,false,c);p.age=18+k%4;p.rating=45+(k*7)%25;a.players.push(p);}}`;

function france() {
  const h = context(437493);
  h.run(`start(0, 'france'); ${FILL}
    var CDJiff = (${jiff.factory.toString()})(); CDJiff.initialize(S); CDJiff.installHooks();
    var rawBuild = buildSheet;
    var CDEsp = (${espoirs.factory.toString()})(); CDEsp.installHooks();`);
  return h;
}

test('Objectif annuel : moyenne 7, de 3 à 11, tiré par club et saison', () => {
  const h = france();
  const goals = JSON.parse(h.run(`JSON.stringify(Array.from({length: 40}, (_, season) => S.clubs.map(c => CDEsp.seasonGoal({season: season + 1}, c.id))).flat())`));
  const mean = goals.reduce((a, b) => a + b, 0) / goals.length;
  assert.ok(mean > 6.8 && mean < 7.2, String(mean));
  assert.equal(Math.min(...goals), 3);
  assert.equal(Math.max(...goals), 11);
});

test('Une saison de Top 14 : environ 7 Espoirs différents par club, jusqu’à 11, JIFF préservé, prêts rendus', () => {
  const h = france();
  // Contrôle JIFF à chaque journée : la feuille avec Espoirs ne compte jamais moins de JIFF
  // (plafonné à l'exigence de 16) que la feuille d'origine.
  const worst = JSON.parse(h.run(`(function () {
    let worst = 0, checked = 0;
    for (let w = 0; w < 34; w++) {
      for (const c of S.clubs) {
        if (c.id === S.club || S.phase !== 'league') continue;
        const f = CDFranceCompetition.currentFixtures(S).find(x => x.pair.includes(c.id));
        if (!f || f.phase !== 'league') continue;
        const base = rawBuild(c), final = buildSheet(c);
        const count = sheet => [...sheet.lineup, ...sheet.bench].filter(id => CDJiff.isJiff(S, c.players.find(p => p.id === id))).length;
        const need = CDJiff.subjectLeagues(S).elite?.includes(c.id) || CDJiff.subjectLeagues(S).accession?.includes(c.id) ? Math.min(count(base), 16) : 0;
        worst = Math.min(worst, count(final) - need); checked++;
        const ids = [...final.lineup, ...final.bench].filter(Boolean);
        if (new Set(ids).size !== ids.length) throw Error('doublon dans la feuille ' + c.abbr);
      }
      finishRound();
    }
    return JSON.stringify(worst);
  })()`));
  assert.ok(worst >= 0, 'JIFF dégradé : ' + worst);
  const r = JSON.parse(h.run(`const rows = Object.values(S.espoirsMatch.clubs);
    JSON.stringify({ n: rows.length, mean: rows.reduce((a, r) => a + r.used.length, 0) / rows.length,
      max: Math.max(...rows.map(r => r.used.length)), min: Math.min(...rows.map(r => r.used.length)),
      qmean: rows.reduce((a, r) => a + r.q, 0) / rows.length,
      perSheet: rows.reduce((a, r) => a + r.total, 0) / rows.reduce((a, r) => a + r.sheets, 0),
      loans: S.clubs.flatMap(c => c.players).filter(p => p.espoirLoan).length,
      ids: (() => { const all = [...S.clubs.flatMap(c => c.players), ...S.aiRoster.academies.flatMap(a => a.players), ...S.development.academy].map(p => p.id); return [all.length, new Set(all).size]; })(),
      valid: CDEsp.validate(S), phase: S.phase })`));
  assert.ok(r.n >= 28);
  // Moyenne observée de la saison : proche de l'objectif (7), un peu en dessous quand un centre manque de profils.
  assert.ok(r.mean >= 5.6 && r.mean <= 8.4, 'moyenne ' + r.mean);
  assert.ok(r.max <= 11 && r.min >= 3, `min ${r.min} max ${r.max}`);
  assert.ok(Math.abs(r.mean - r.qmean) <= 1.2, `objectif ${r.qmean} contre ${r.mean}`);
  assert.ok(r.perSheet > .6 && r.perSheet < 2, 'Espoirs par feuille ' + r.perSheet);
  assert.equal(r.loans, 0, 'aucun prêt ne reste en fin de saison');
  assert.equal(r.ids[0], r.ids[1], 'identifiants uniques entre effectifs et centres');
  assert.equal(r.valid, true);
  // La moyenne est archivée à la saison suivante.
  h.run('advanceSeason(); CDEsp.ensure(S);');
  const hist = JSON.parse(h.run('JSON.stringify(S.espoirsMatch.history)'));
  assert.equal(hist.length, 1);
  assert.ok(hist[0].average >= 5.6 && hist[0].average <= 8.4 && hist[0].max <= 11);
});

test('Les prêts sont rendus au centre à la fin de la journée et la feuille d’un club reste stable dans la journée', () => {
  const h = france();
  const r = JSON.parse(h.run(`(function () {
    const club = S.clubs.find(c => c.id !== S.club && CDFranceCompetition.currentFixtures(S).some(f => f.pair.includes(c.id)));
    const before = S.aiRoster.academies.find(a => a.clubId === club.id).players.length;
    const first = buildSheet(club), second = buildSheet(club);
    const during = club.players.filter(p => p.espoirLoan).length;
    const inAcademy = S.aiRoster.academies.find(a => a.clubId === club.id).players.length;
    finishRound();
    return JSON.stringify({ stable: JSON.stringify(first) === JSON.stringify(second), during, moved: before - inAcademy,
      after: club.players.filter(p => p.espoirLoan).length, back: S.aiRoster.academies.find(a => a.clubId === club.id).players.length,
      before, academyFlag: S.aiRoster.academies.find(a => a.clubId === club.id).players.every(p => p.academy === true && p.contractEnd == null) });
  })()`));
  assert.equal(r.stable, true);
  assert.equal(r.moved, r.during, 'prêtés = retirés du centre (jamais copiés)');
  assert.equal(r.after, 0);
  assert.equal(r.back, r.before);
  assert.equal(r.academyFlag, true, 'les Espoirs rendus retrouvent leur statut de centre');
});

test('Le club du joueur n’est jamais touché, ni hors championnat, ni avec une feuille choisie à la main', () => {
  const h = france();
  const r = JSON.parse(h.run(`(function () {
    const own = S.clubs[S.club], other = S.clubs.find(c => c.id !== S.club);
    const a = JSON.stringify(buildSheet(own)), b = JSON.stringify(rawBuild(own));
    const manual = buildSheet(other, rawBuild(other).lineup, rawBuild(other).bench);
    const manualEspoirs = other.players.filter(p => p.espoirLoan).length;
    return JSON.stringify({ same: a === b, manualEspoirs, state: S.espoirsMatch ? Object.keys(S.espoirsMatch.clubs).includes(String(S.club)) : false, manualSame: JSON.stringify(manual) === JSON.stringify(rawBuild(other)) });
  })()`));
  assert.equal(r.same, true);
  assert.equal(r.manualEspoirs, 0);
  assert.equal(r.manualSame, true);
  assert.equal(r.state, false);
});

test('Fenêtres internationales : davantage d’Espoirs quand des joueurs sont partis en sélection', () => {
  const h = context();
  h.ctx.nativeWorldRegistryText = JSON.stringify(registry);
  h.run(worldVm.bootstrap());
  h.run(`CDWorldCareer.start(0, 'world', true);
    while (!CDWorldCareer.userFixture(S)) CDWorldCareer.finishWeek();
    ${FILL}
    var CDJiff = null; var CDEsp = (${espoirs.factory.toString()})(); CDEsp.installHooks();`);
  const r = JSON.parse(h.run(`(function () {
    const fixtures = CDWorldCareer.fixtures(S).filter(f => f.phase === 'league');
    const clubs = [...new Set(fixtures.flatMap(f => [f.homeId, f.awayId]))].map(id => S.clubs[id]).filter(c => c.id !== S.club && S.aiRoster.academies.some(a => a.clubId === c.id));
    const date = fixtures[0].date;
    const away = clubs.filter((c, i) => i % 2 === 0), home = clubs.filter((c, i) => i % 2 === 1);
    // La moitié des clubs perd cinq joueurs en sélection ce week-end.
    S.national = { role: { club: true, nation: 'FRA' }, career: { callups: [{ nation: 'FRA', from: '2026-01-01', through: '2030-01-01',
      playerIds: away.flatMap(c => c.players.slice(0, 5).map(p => p.id)) }] } };
    const size = list => list.map(c => { const p = CDEsp.plan(S, c); return p.ids.length; });
    const avg = list => { const v = size(list); return v.reduce((a, b) => a + b, 0) / v.length; };
    return JSON.stringify({ n: clubs.length, withDuty: avg(away), without: avg(home),
      flagged: away.filter(c => CDEsp.plan(S, c).window).length, flaggedOthers: home.filter(c => CDEsp.plan(S, c).window).length });
  })()`));
  assert.ok(r.n >= 20, String(r.n));
  assert.ok(r.withDuty > r.without + .8, `fenêtre ${r.withDuty} contre ${r.without}`);
  assert.ok(r.flagged >= r.n / 2 - 2 && r.flaggedOthers === 0);
});

test('Validation : état hostile refusé, partie sans module acceptée', () => {
  const h = france();
  h.run('for (let w = 0; w < 3; w++) finishRound();');
  assert.equal(h.run('CDEsp.validate(S)'), true);
  assert.equal(h.run('CDEsp.validate({season: 1, clubs: []})'), true);
  for (const mutation of ['S.espoirsMatch.version = 2', 'S.espoirsMatch.extra = 1', 'S.espoirsMatch.season = S.season + 1',
    'Object.values(S.espoirsMatch.clubs)[0].q = 99', 'Object.values(S.espoirsMatch.clubs)[0].used.push("é é")', 'Object.values(S.espoirsMatch.clubs)[0].plan = {key: "x"}',
    'S.espoirsMatch.clubs[999] = Object.values(S.espoirsMatch.clubs)[0]']) {
    h.ctx.original = h.run('JSON.stringify(S)');
    h.run(mutation);
    assert.throws(() => h.run('CDEsp.validate(S)'), /Espoirs en feuille/, mutation);
    h.run('S = JSON.parse(original)');
  }
  // L'état survit à une sérialisation complète.
  const round = JSON.parse(h.run('JSON.stringify(S)'));
  assert.deepEqual(Object.keys(round.espoirsMatch.clubs).length > 0, true);
});
