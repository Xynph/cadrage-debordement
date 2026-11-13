'use strict';
// Statut JIFF et quota LNR (décision de Léo du 12/11/2026 : « comme dans la réalité »).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./france-harness.cjs');
const { factory } = require('../native/engine/jiff.cjs');

function setup() {
  const h = context(437493);
  h.run(`start(0, 'france'); var CDJiff = (${factory.toString()})();`);
  return h;
}

test('Initialisation : environ 70 % de JIFF dans chaque club français, les jeunes comptent leurs saisons au centre', () => {
  const h = setup();
  const result = JSON.parse(h.run(`CDJiff.initialize(S);
    const pros = S.clubs.flatMap(c => c.players);
    const academy = S.development.academy;
    JSON.stringify({ share: pros.filter(p => CDJiff.isJiff(S, p)).length / pros.length,
      perClub: S.clubs.map(c => c.players.filter(p => CDJiff.isJiff(S, p)).length / c.players.length),
      academy: academy.map(p => [p.age, ...CDJiff.getStatus(S, p.id)]), validate: CDJiff.validate(S),
      again: CDJiff.initialize(S) });`));
  assert.ok(result.share > .68 && result.share < .74, String(result.share));
  assert.ok(result.perClub.every(share => share >= .7 && share < .76), String(result.perClub));
  assert.ok(result.academy.every(([age, jiff, centre]) => centre === Math.max(0, Math.min(3, age - 16)) && jiff === (centre >= 3 ? 1 : 0)));
  assert.equal(result.validate, true);
  assert.equal(result.again, false, 'Une seconde initialisation ne réécrit pas les statuts');
});

test('Barème : retrait de points sous 16 JIFF de moyenne, prime du fonds à partir de 17', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify({
    deductions: [16, 15.5, 15, 13, 5].map(CDJiff.deductionFor),
    bonuses: [[16.9, 'elite'], [17, 'elite'], [18, 'elite'], [20, 'elite'], [17, 'accession'], [21, 'accession']].map(([a, l]) => CDJiff.bonusFor(l, a)) })`));
  assert.deepEqual(r.deductions, [0, 1, 2, 6, 10]);
  assert.deepEqual(r.bonuses, [0, 220000, 320000, 320000, 190000, 280000]);
});

test('Fin de saison : un jeune devient JIFF après trois saisons au centre, le club paie son retard la saison suivante', () => {
  const h = setup();
  const r = JSON.parse(h.run(`CDJiff.initialize(S);
    const young = S.development.academy.find(p => !CDJiff.isJiff(S, p));
    CDJiff.setStatus(S, young.id, [0, 2, 0]);
    const other = S.clubs.find(c => c.id !== S.club && CDJiff.subjectLeagues(S).elite?.includes(c.id));
    S.jiff.counts[other.id] = [26, 26 * 14];
    S.jiff.counts[S.club] = [26, 26 * 18];
    const cash = S.clubs[S.club].cash;
    const pending = CDJiff.closeSeason(S, S.season);
    const during = CDJiff.deduction(S, other.id);
    S.season++; CDJiff.openSeason(S, pending);
    JSON.stringify({ during, young: CDJiff.isJiff(S, young), deduction: CDJiff.deduction(S, other.id), own: CDJiff.deduction(S, S.club),
      bonus: S.clubs[S.club].cash - cash, results: S.jiff.results.length, counts: Object.keys(S.jiff.counts).length, validate: CDJiff.validate(S) });`));
  assert.equal(r.during, 0, 'Le classement de la saison terminée n’est pas modifié');
  assert.equal(r.young, true);
  assert.equal(r.deduction, 4);
  assert.equal(r.own, 0);
  assert.ok(r.bonus > 0, 'Le club au-dessus de 17 touche la prime');
  assert.equal(r.results, 2);
  assert.equal(r.counts, 0, 'Les feuilles sont remises à zéro pour la nouvelle saison');
  assert.equal(r.validate, true);
});

test('Classement : le retrait de points JIFF compte au classement général', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => { CDJiff.initialize(S);
    const elite = CDJiff.subjectLeagues(S).elite;
    for (const id of elite) S.clubs[id].points = 40;
    S.jiff.deductions[elite[0]] = 3;
    const order = CDFranceCompetition.ranked(S, 'elite').map(c => c.id);
    return JSON.stringify({ last: order.at(-1), penalized: elite[0] }); })()`));
  assert.equal(r.last, r.penalized);
});

test('Composition automatique : la feuille de l’ordinateur remonte vers 16 JIFF sans toucher une feuille choisie à la main', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => { CDJiff.initialize(S);
    const elite = CDJiff.subjectLeagues(S).elite;
    const c = S.clubs[elite.find(id => id !== S.club)];
    // Pire cas : seuls les remplaçants potentiels sont JIFF.
    const sheet0 = buildSheet(c, [], []);
    for (const p of c.players) CDJiff.setStatus(S, p.id, [0, 0, 0]);
    const titular = new Set([...sheet0.lineup, ...sheet0.bench]);
    for (const p of c.players) if (!titular.has(p.id)) CDJiff.setStatus(S, p.id, [1, 0, 5]);
    const before = [...sheet0.lineup, ...sheet0.bench].filter(id => CDJiff.isJiff(S, c.players.find(p => p.id === id))).length;
    const after = CDJiff.comply(S, c, sheet0);
    const count = [...after.lineup, ...after.bench].filter(id => CDJiff.isJiff(S, c.players.find(p => p.id === id))).length;
    const reserve = c.players.filter(p => !titular.has(p.id) && !p.injury).length;
    return JSON.stringify({ before, count, reserve, unique: new Set([...after.lineup, ...after.bench].filter(Boolean)).size === [...after.lineup, ...after.bench].filter(Boolean).length }); })()`));
  console.log(JSON.stringify(r));
  assert.equal(r.before, 0);
  // Les échanges restent limités aux postes compatibles : au moins les trois quarts des JIFF disponibles entrent.
  assert.ok(r.count >= Math.min(16, Math.ceil(r.reserve * .75)), JSON.stringify(r));
  assert.equal(r.unique, true, 'Aucun joueur n’apparaît deux fois');
});

test('Validation stricte : un état JIFF altéré est refusé', () => {
  const h = setup();
  h.run('CDJiff.initialize(S)');
  for (const breakage of [
    '(b => b[Object.keys(b)[0]] = [2, 0, 0])(Object.values(S.jiff.players)[0])',
    'S.jiff.players.b99 = { x: [0, 0, 0] }',
    'S.jiff.deductions[0] = 50',
    'S.jiff.extra = 1',
    'S.jiff.results.push({ season: 1, clubId: 0, league: "elite", sheets: 1, average: 30, deduction: 0, bonus: 0 })',
  ]) {
    assert.throws(() => h.run(`(() => { const saved = JSON.parse(JSON.stringify(S.jiff)); try { ${breakage}; CDJiff.validate(S); } finally { S.jiff = saved; } })()`), /JIFF/);
  }
});

test('Fin de saison : un jeune pro du club devient JIFF par la licence, annoncé dans le fil', () => {
  const h = setup();
  const r = JSON.parse(h.run(`CDJiff.initialize(S);
    const young = S.clubs[S.club].players.find(p => p.age <= 23) || Object.assign(S.clubs[S.club].players[0], { age: 22 });
    CDJiff.setStatus(S, young.id, [0, 0, 4]);
    CDJiff.closeSeason(S, S.season);
    JSON.stringify({ jiff: CDJiff.isJiff(S, young), news: S.news.filter(t => String(t).includes(young.name) && String(t).includes('cinq saisons de licence')).length });`));
  assert.equal(r.jiff, true);
  assert.equal(r.news, 1);
});
