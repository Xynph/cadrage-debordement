'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {factory} = require('../native/engine/nationale.cjs');
const geometry = require('../native/engine/nationale-calendar-2026-27.json');
const N = factory(geometry);
const ids = (first, count) => Array.from({length: count}, (_, i) => first + i);
const nat = ids(88, 14);
const elite = ids(0, 14);
const accession = ids(14, 16);
const members = {elite, accession, nationale: nat};
const ranks = {elite, accession};
const anchor = '2026-08-17';

function finalResult(f, score, tries = [0, 0], extra = {}) {
  return {fixtureId: f.id, competitionId: f.competitionId, phase: f.phase,
    pair: [f.homeId, f.awayId], score, tries, ...extra};
}

function regular(a, b, score, tries = [0, 0], extra = {}) {
  return {fixtureId: `example-${a}-${b}`, competitionId: 'nationale', phase: 'league',
    pair: [a, b], score, tries, ...extra};
}

test('Les 182 rencontres publiées, réciproques et datées, ouvrent le vendredi 21 août', () => {
  const cal = N.calendarFixtures({clubs:nat,season:2026,anchor,weeks:46});
  assert.equal(cal.length,182);
  assert.equal(cal.map(f=>f.date).sort()[0],'2026-08-21');
  assert.equal(cal.map(f=>f.date).sort().at(-1),'2027-04-17');
  assert.equal(new Set(cal.map(f=>f.id)).size,182);
  assert.equal(new Set(cal.map(f=>[f.homeId,f.awayId].join(':'))).size,182);
  assert.ok(cal.every(f=>f.timezone==='Europe/Paris'&&f.dateStatus==='published'&&/^\d{2}:\d{2}$/.test(f.kickoffLocal)));
  for(const id of nat){
    assert.equal(cal.filter(f=>f.homeId===id).length,13);
    assert.equal(cal.filter(f=>f.awayId===id).length,13);
    assert.equal(new Set(cal.filter(f=>f.homeId===id||f.awayId===id).map(f=>f.week)).size,26);
  }
});

test('S2 exige une convention explicite et réemploie des créneaux déterministes', () => {
  const clubs = nat.with(0, 28);
  assert.throws(() => N.calendarFixtures({season: 2027, clubs}), /convention/);
  const opts = {season: 2027, clubs, seasonModel: N.FROZEN_MODEL};
  const s2 = N.calendarFixtures(opts);
  assert.deepEqual(s2, N.calendarFixtures(opts));
  assert.equal(s2.length, 182);
  assert.equal(s2[0].date, '2027-08-20');
  assert.equal(s2[0].scheduleSource, 'generated-frozen-format');
  assert(s2.some(f => f.homeId === 28 || f.awayId === 28));
  assert(!s2.some(f => f.homeId === 88 || f.awayId === 88));
});

test('4/2/0, bonus à trois essais et défaite de sept, terrain sans malus administratif', () => {
  assert.deepEqual(N.terrainPoints([24, 17], [4, 1]), [5, 1]);
  assert.deepEqual(N.terrainPoints([24, 16], [3, 1]), [4, 0]);
  assert.deepEqual(N.terrainPoints([15, 21], [3, 0]), [2, 4]);
  assert.deepEqual(N.terrainPoints([15, 15], [3, 0]), [3, 2]);
  assert.throws(() => N.terrainPoints([9, 7], [2, 1]), /score/);
  const rows = N.table(nat, [
    regular(88, 89, [15, 12]), regular(88, 90, [9, 15]), regular(89, 90, [42, 0]),
    {...regular(88, 91, [0, 25], [0, 0]), administrative: {kind: 'forfeit', side: 0}},
    {...regular(91, 88, [18, 17]), phase: 'barrage'},
  ], {deductions: {[91]: 2}});
  const byId = id => rows.find(r => r.clubId === id);
  assert.equal(byId(88).played, 3);
  assert.equal(byId(88).forfeits, 1);
  assert.equal(byId(88).points, 3);
  assert.equal(byId(91).points, 3);
  assert.equal(byId(91).terrain, 5);
  assert.equal(byId(91).pf, 25);
});

test('le mini-classement prime le goal-average général et les données manquantes sont signalées', () => {
  const rows = N.table(nat, [
    regular(88, 89, [15, 12]), regular(88, 90, [9, 15]), regular(89, 90, [42, 0]),
  ]);
  assert.deepEqual(rows.slice(0, 2).map(r => r.clubId), [88, 89]);
  assert(rows[0].diff < rows[1].diff);
  assert.equal(rows[0].points, rows[1].points);
  assert.equal(rows.at(-1).unresolvedTie, true);
  assert.equal(rows.at(-1).unavailableTieBreak, 'suspensionWeeks');
  const ordered = N.table(nat, [], {tieBreaks: {drawOrder: Object.fromEntries(nat.slice().reverse().map((id, i) => [id, i]))}});
  assert.equal(ordered[0].clubId, 101);
  assert.equal(ordered[0].tieResolution, 'game-draw');
  const official = N.table(nat, [], {tieBreaks: {
    suspensionWeeks: Object.fromEntries(nat.map(id => [id, 101 - id])),
  }});
  assert.equal(official[0].clubId, 101);
  assert.equal(official[0].unresolvedTie, undefined);
});

test('la table vérifie les fixtures, ignore les autres compétitions et interdit le doublon', () => {
  const fixtures = N.calendarFixtures({clubs: nat});
  const result = finalResult(fixtures[0], [24, 17], [4, 1]);
  assert.equal(N.table(nat, [result], {fixtures})[0].bonus, 1);
  assert.throws(() => N.table(nat, [result, result], {fixtures}), /doublon/);
  assert.throws(() => N.table(nat, [{...result, pair: result.pair.slice().reverse()}], {fixtures}), /calendrier/);
  assert.equal(N.table(nat, [{...result, competitionId: 'elite'}], {fixtures})[0].played, 0);
  assert.throws(() => N.playoffSeeds(N.table(nat, [result], {fixtures})), /26/);
  const all = fixtures.map((f, i) => finalResult(f, i % 3 ? [21, 3] : [3, 21]));
  const drawOrder = Object.fromEntries(nat.map((id, i) => [id, i]));
  const rows = N.table(nat, all, {fixtures, tieBreaks: {drawOrder}});
  assert.equal(N.playoffSeeds(rows).length, 6);
  assert.throws(() => N.playoffSeeds(rows.with(0, {...rows[0], playoffIneligible: true})), /homologuer/);
  const last = fixtures.at(-1);
  const lateForfeit = finalResult(last, [0, 25], [0, 0], {administrative: {kind: 'forfeit', side: 0}});
  assert.equal(N.table(nat, [lateForfeit], {fixtures}).find(r => r.clubId === last.homeId).playoffIneligible, true);
});

test('3–6, 4–5, demi-finales fixes et finale neutre, avec validation de provenance des résultats', () => {
  const seeds = nat.slice(0, 6);
  const barrage = N.knockoutFixtures({phase: 'barrage', seeds});
  assert.deepEqual(barrage.map(f => [f.homeId, f.awayId]), [[90, 93], [91, 92]]);
  assert.deepEqual(barrage.map(f => [f.date, f.week, f.venueHostId]), [['2027-05-01', 36, 90], ['2027-05-01', 36, 91]]);
  assert.deepEqual(N.knockoutFixtures({phase: 'semi', seeds}), []);
  const results = [finalResult(barrage[0], [10, 18]), finalResult(barrage[1], [15, 22])];
  const semi = N.knockoutFixtures({phase: 'semi', seeds, results});
  assert.deepEqual(semi.map(f => [f.homeId, f.awayId]), [[88, 92], [89, 93]]);
  assert.equal(semi[0].date, '2027-05-08');
  results.push(finalResult(semi[0], [10, 18]), finalResult(semi[1], [19, 12]));
  const [f] = N.knockoutFixtures({phase: 'final', seeds, results});
  assert.deepEqual([f.homeId, f.awayId, f.date, f.neutral, f.venueHostId], [92, 89, '2027-05-15', true, null]);
  assert.deepEqual(N.finalOutcome({seeds, results: [...results, finalResult(f, [18, 12])]}),
    {champion: 92, finalist: 89});
  assert.throws(() => N.knockoutFixtures({phase: 'semi', seeds, results: [...results, results[0]]}), /doublon/);
  assert.throws(() => N.knockoutFixtures({phase: 'semi', seeds, results: [{...results[0], pair: [91, 93]}, results[1]]}), /rencontre/);
});

test('KO FFR applique 20 minutes, essais puis cinq tirs et relance par autres joueurs', () => {
  const f = N.knockoutFixtures({phase: 'barrage', seeds: nat.slice(0, 6)})[0];
  assert.deepEqual(N.knockoutWinner(finalResult(f, [18, 15])), {winner: 90, method: 'score'});
  assert.throws(() => N.knockoutWinner(finalResult(f, [18, 18])), /prolongation/);
  const base = {regulationScore: [15, 15], extraMinutes: 20};
  assert.deepEqual(N.knockoutWinner(finalResult(f, [18, 18], [3, 0], {extra: base})),
    {winner: 90, method: 'tries'});
  const kickers = [ids(1, 7), ids(11, 7)];
  const attempts = Array.from({length: 7}, (_, i) => kickers.map((side, team) => ({
    playerId: side[i], scored: i === 6 ? team === 1 : i % 2 === 0,
  })));
  const extra = {...base, kickers, attempts};
  assert.deepEqual(N.knockoutWinner(finalResult(f, [18, 18], [2, 2], {extra})),
    {winner: 93, method: 'shootout'});
  assert.throws(() => N.knockoutWinner(finalResult(f, [18, 18], [2, 2], {
    extra: {...extra, attempts: attempts.with(5, attempts[0])},
  })), /buteur/);
  assert.throws(() => N.knockoutWinner(finalResult(f, [18, 18], [2, 2], {
    extra: {...extra, attempts: [...attempts, attempts[5]]},
  })), /décisif/);
});

test('Access Match Pro D2 à domicile du finaliste, date publiée comme fenêtre', () => {
  const options = {nationaleFinal: {champion: 88, finalist: 89}, proD2Rank: accession, approval: {88: true, 89: true}};
  const pending = N.accessPlan(options);
  assert.equal(pending.status, 'awaiting-match');
  const f = pending.fixture;
  assert.deepEqual([f.homeId, f.awayId, f.date, f.simulationDate, f.week], [89, 28, null, '2027-05-29', 40]);
  assert.deepEqual(f.dateWindow, ['2027-05-29', '2027-05-30']);
  assert.equal(f.competitionId, 'access-nationale');
  const won = N.accessPlan({...options, result: finalResult(f, [24, 15])});
  assert.deepEqual([won.promoted, won.relegated], [[88, 89], [29, 28]]);
  const lost = N.accessPlan({...options, result: finalResult(f, [15, 24])});
  assert.deepEqual([lost.promoted, lost.relegated], [[88], [29]]);
  assert.throws(() => N.accessPlan({...options, result: finalResult(f, [15, 24], [0, 0], {winner: 89})}), /vainqueur/);
  assert.equal(N.accessPlan({...options, result: finalResult(f, [18, 18])}).status, 'awaiting-access-decision');
});

test('homologation et maintien du 15e ou des deux derniers selon le livret', () => {
  const options = {nationaleFinal: {champion: 88, finalist: 89}, proD2Rank: accession};
  assert.equal(N.accessPlan(options).status, 'awaiting-approval');
  const onlyChampion = N.accessPlan({...options, approval: {88: true, 89: false}});
  assert.deepEqual([onlyChampion.status, onlyChampion.promoted, onlyChampion.relegated, onlyChampion.retained], ['ready', [88], [29], [28]]);
  const none = N.accessPlan({...options, approval: {88: false, 89: false}});
  assert.deepEqual([none.status, none.promoted, none.relegated, none.retained], ['ready', [], [], [28, 29]]);
  const onlyFinalist = {...options, approval: {88: false, 89: true}};
  assert.equal(N.accessPlan(onlyFinalist).status, 'awaiting-committee');
  const ruling = N.accessPlan({...onlyFinalist, committeeDecision: {promoted: 89, reference: 'Décision test'}});
  assert.deepEqual([ruling.promoted, ruling.relegated, ruling.retained], [[89], [29], [28]]);
});

test('les deux frontières combinées conservent 44 clubs, sans transit ni candidat EPCR de Nationale', () => {
  const lower = {nationaleFinal: {champion: 88, finalist: 89}, approval: {88: true, 89: true}};
  const f = N.accessPlan({...lower, proD2Rank: accession}).fixture;
  for (const topWin of [false, true]) for (const natWin of [false, true]) {
    const topMovement = {promoted: topWin ? [14, 15] : [14], relegated: topWin ? [13, 12] : [13]};
    const result = finalResult(f, natWin ? [20, 15] : [15, 20]);
    const out = N.combineFrenchMovements({members, ranks, topMovement, lower: {...lower, result}});
    assert.equal(out.status, 'ready');
    assert.deepEqual([out.elite.length, out.accession.length, out.nationale.length], [14, 16, 14]);
    assert.equal(new Set([...out.elite, ...out.accession, ...out.nationale]).size, 44);
    assert.deepEqual(out.elite.filter(id => accession.includes(id)), topMovement.promoted);
    assert(out.accession.includes(88));
    assert.equal(out.accession.includes(89), natWin);
    assert.equal(out.nationale.includes(28), natWin);
    assert.equal(out.nationale[0], 29);
    assert.equal(out.nationale[1], natWin ? 28 : 89);
    assert.deepEqual(out.nationale.slice(2), nat.slice(2));
    assert.deepEqual(new Set(out.epcrCandidateOrder), new Set(out.elite));
    assert(!out.epcrCandidateOrder.some(id => nat.includes(id)));
    assert.equal(out.lowerBoundary, 'closed-without-nationale-2');
  }
  assert.throws(() => N.combineFrenchMovements({members, ranks, topMovement: {promoted: [29], relegated: [13]}, lower}), /promotion/);
  assert.throws(() => N.combineFrenchMovements({members, ranks, topMovement: {promoted: [14], relegated: [13], accession}, lower}), /partition/);
  assert.equal(N.combineFrenchMovements({members, ranks, topMovement: {promoted: [14], relegated: [13]}, lower}).status, 'awaiting-match');
});

test('cartes FFR B/C vérifiées, inconnues visibles, sans inférence par nationalité ou JIFF', () => {
  const card = (type, count) => Array(count).fill(type);
  assert.deepEqual(N.lineupCards([...card('A', 19), ...card('B', 3), 'C']), {status: 'compliant', b: 3, c: 1, unknown: 0});
  assert.equal(N.lineupCards([...card('A', 18), ...card('B', 4), 'C']).status, 'exceeded');
  assert.equal(N.lineupCards([...card('A', 21), 'C', 'C']).status, 'exceeded');
  assert.equal(N.lineupCards([...card('A', 22), null]).status, 'unknown');
  assert.throws(() => N.lineupCards([...card('A', 22), 'FR']), /carte/);
});
