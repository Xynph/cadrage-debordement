'use strict';
// Audit des flux financiers en carrière Monde (world-champ), budget de saison réaliste (économie par défaut
// depuis #699). Vraies semaines jouées au worker (tests/helpers/carriere-monde.cjs) : chaque variation de
// caisse des clubs gérés est rapprochée à l'euro de ses flux (facturation rejouée avec le barème de
// production, indemnités des accords entre clubs), le club joué de son grand livre ; une contre-épreuve
// isolée rejoue la vraie facturation. Des cas construits vérifient qu'un écart reste « unknown ».
const {test} = require('node:test'), assert = require('node:assert/strict');
const {reconcile, billingReplay, upkeep} = require('../native/engine/world-finance-flow-audit.cjs');
const {run} = require('../ci/world-finance-flow-audit.cjs');

// Semaines 0 à 12 de la saison 1 (graine 4242, club 102) : la semaine 12 porte le premier accord entre
// deux clubs gérés (indemnité payée à l'accord, hors facturation).
const WEEKS = 13;
let report = null;
const audit = () => report ??= run({seed: 4242, weeks: WEEKS, club: 102});

test('Every managed club reconciles to the euro, every week, under the season budget', () => {
  const r = audit();
  assert.equal(r.passed, true); assert.equal(r.mode, 'world-champ'); assert.equal(r.weeks.length, WEEKS);
  for (const w of r.weeks) {
    assert.ok(w.ai.clubs > 100, 'all managed clubs of the world are audited');
    assert.equal(w.ai.reconciled, w.ai.clubs, 'week ' + w.week + ': ' + JSON.stringify(w.rows.filter(x => x.status === 'unknown').slice(0, 3)));
    assert.equal(w.ai.unknown, 0); assert.equal(w.ai.residual, 0);
    assert.equal(w.ai.billingMatched, w.ai.clubs, 'billing replayed by the production season-budget schedule');
    assert.equal(w.ai.transferNet, 0, 'transfer fees move cash between clubs, never create it');
    for (const row of w.rows.filter(x => x.kind === 'ai')) {
      assert.equal(row.conserved, true); assert.equal(row.billing.replayMatchesEngine, true);
      assert.deepEqual(row.unknownWrites, []);
      assert.ok(row.billing.components.some(e => e.title.endsWith(' · Salaires des joueurs') && e.amount < 0), 'payroll is billed');
    }
    const human = w.rows.find(x => x.kind === 'human-ledger');
    assert.equal(human.status, 'reconciled-ledger'); assert.equal(human.residual, 0);
  }
  assert.ok(r.weeks.filter(w => w.results > 0).length >= 5, 'match weeks are audited');
});

test('Interclub transfer fees are traced outside the weekly billing and match the recorded accord', () => {
  const r = audit(), weeks = r.weeks.filter(w => w.accords.length);
  assert.ok(weeks.length >= 1, 'the audited window contains at least one accord between managed clubs');
  for (const w of weeks) for (const a of w.accords) {
    const seller = w.rows.find(x => x.clubId === a.vendeurId), buyer = w.rows.find(x => x.clubId === a.acheteurId);
    assert.ok(a.montant > 0);
    assert.equal(seller.status, 'reconciled'); assert.equal(buyer.status, 'reconciled');
    assert.ok(seller.transfers.accords.includes(a.id) && buyer.transfers.accords.includes(a.id));
    assert.equal(seller.delta, seller.billing.expected + seller.transfers.expected);
    assert.equal(buyer.delta, buyer.billing.expected + buyer.transfers.expected);
  }
});

test('Isolated replay of the real billing preserves RNG and results; one extra wage costs what the budget says', () => {
  const r = audit(), c = r.counterfactual;
  assert.equal(r.weeks[0].billingReplay.matched, r.weeks[0].ai.clubs);
  assert.ok(c.rngUnchanged && c.sportsUnchanged && c.otherStateIdentical && c.duplicateWeekRefused);
  assert.equal(c.cashDeltaDifference, c.expectedDifference); assert.ok(c.cashDeltaDifference < 0);
});

// Cas construits : deux clubs gérés et le club joué, barème réel de club-budget.cjs.
function fixture() {
  const forces = [0, 1, 2].map(id => ({id, division: 'champ', base: 60 + id}));
  const args = id => ({forces, clubId: id, masseHebdo: 40000, semaines: 40, receptions: 12, domicile: id === 1, neutre: false, phase: 'league',
    resultats: [], gere: true, repere: '1|3', libelle: '', formation: null, investissement: 0, accueil: 1, marge: 0, aideRelegation: 0, remboursement: 0});
  const billing = {};
  for (const id of [1, 2]) { const cap = {args: args(id), compte: {imprevu: 0, fraisMatch: 0}}; cap.ecritures = billingReplay(cap); billing[id] = cap; }
  const clubs = [0, 1, 2].map(id => ({id, cash: 1000000, players: [{id: 'p' + id, salary: 40000}]}));
  const a = {mode: 'world-champ', season: 1, week: 3, phase: 'league', club: 0, clubs, facilities: {0: 2, 1: 2, 2: 3}, ledger: [], accordsIA: []};
  const b = structuredClone(a); b.week = 4;
  const writes = [];
  for (const id of [1, 2]) {
    const d = billing[id].ecritures.reduce((n, e) => n + e.amount, 0) - upkeep(a.facilities[id]);
    b.clubs[id].cash += d; writes.push({clubId: id, delta: d, fn: 'worldWeeklyEconomy'});
  }
  return {a, b, trace: {writes, billing}};
}
test('A constructed week with billing and an accord reconciles', () => {
  const {a, b, trace} = fixture();
  b.accordsIA.push({id: 'ia-9', vendeurId: 2, acheteurId: 1, montant: 50000});
  b.clubs[1].cash -= 50000; b.clubs[2].cash += 50000;
  trace.writes.push({clubId: 1, delta: -50000, fn: 'calIANouvelAccord'}, {clubId: 2, delta: 50000, fn: 'calIANouvelAccord'});
  const r = reconcile(a, b, trace);
  assert.equal(r.ai.reconciled, 2); assert.equal(r.ai.transferClubs, 2);
  assert.equal(r.rows.find(x => x.clubId === 0).status, 'reconciled-ledger');
});
test('Unexplained cash, unknown engine flows or a forged billing stay unknown, never attributed to a made-up flow', () => {
  let f = fixture(); f.b.clubs[1].cash += 999;                       // écriture non tracée
  assert.equal(reconcile(f.a, f.b, f.trace).rows[1].status, 'unknown');
  f = fixture(); f.b.clubs[1].cash += 999; f.trace.writes.push({clubId: 1, delta: 999, fn: 'mystere'}); // flux inconnu
  let row = reconcile(f.a, f.b, f.trace).rows[1];
  assert.equal(row.status, 'unknown'); assert.deepEqual(row.unknownWrites, [{fn: 'mystere', delta: 999}]);
  f = fixture(); f.b.clubs[1].cash -= 50000; f.trace.writes.push({clubId: 1, delta: -50000, fn: 'calIANouvelAccord'}); // indemnité sans accord
  assert.equal(reconcile(f.a, f.b, f.trace).rows[1].status, 'unknown');
  f = fixture(); f.trace.billing[1].ecritures[0].amount += 1;        // écritures du moteur différentes du barème
  row = reconcile(f.a, f.b, f.trace).rows[1];
  assert.equal(row.billing.replayMatchesEngine, false); assert.equal(row.status, 'unknown');
  f = fixture(); delete f.trace.billing[2];                         // club non facturé
  assert.equal(reconcile(f.a, f.b, f.trace).rows[2].status, 'unknown');
  f = fixture(); f.b.season++;
  assert.throws(() => reconcile(f.a, f.b, f.trace), /no interseason/);
  f = fixture(); f.a.mode = f.b.mode = 'other';
  assert.throws(() => reconcile(f.a, f.b, f.trace), /world-champ/);
});
