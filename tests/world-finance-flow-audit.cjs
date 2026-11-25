'use strict';
// Audit des flux financiers en carrière Monde (world-champ), budget de saison réaliste (économie par défaut
// depuis #699). Vraies semaines jouées au worker (tests/helpers/carriere-monde.cjs) : chaque variation de
// caisse des clubs gérés est rapprochée à l'euro de ses flux (facturation rejouée avec le barème de
// production, indemnités des accords entre clubs), le club joué de son grand livre ; une contre-épreuve
// isolée rejoue la vraie facturation. Des cas construits vérifient qu'un écart reste « unknown ».
const {test} = require('node:test'), assert = require('node:assert/strict');
const {reconcile, reconcileInterseason, billingReplay, upkeep} = require('../native/engine/world-finance-flow-audit.cjs');
const budget = require('../native/engine/club-budget.cjs'), owner = require('../native/engine/club-owner.cjs');
const {run} = require('../ci/world-finance-flow-audit.cjs');

// Semaines 0 à 19 de la saison 1 (graine 4242, club 102) : la semaine 19 porte les premiers accords entre
// deux clubs gérés (indemnité payée à l'accord, hors facturation). Avant la trésorerie de départ réaliste des clubs de
// Championship, de Super Rugby et de D2 japonaise (24/11/2026), le premier accord tombait en semaine 12.
const WEEKS = 20;
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
    resultats: [], gere: true, repere: '1|3', libelle: '', formation: null, investissement: 0, accueil: 1, marge: 0, aideRelegation: 0, remboursement: id === 2 ? 400000 : 0});
  const billing = {};
  for (const id of [1, 2]) { const cap = {args: args(id), compte: {imprevu: 0, fraisMatch: 0}}; cap.ecritures = billingReplay(cap); billing[id] = cap; }
  const clubs = [0, 1, 2].map(id => ({id, cash: 1000000, players: [{id: 'p' + id, salary: 40000}]}));
  // Club 2 rembourse le prêt de son actionnaire : 400 000 € sur 40 semaines, soit 10 000 € cette semaine.
  const a = {mode: 'world-champ', season: 1, week: 3, phase: 'league', club: 0, clubs, facilities: {0: 2, 1: 2, 2: 3}, ledger: [], accordsIA: [],
    debt: {0: 0, 1: 0, 2: 300000}, prets: {2: {restant: 300000}}};
  const b = structuredClone(a); b.week = 4;
  const writes = [];
  for (const id of [1, 2]) {
    const d = billing[id].ecritures.reduce((n, e) => n + e.amount, 0) - upkeep(a.facilities[id]);
    b.clubs[id].cash += d; writes.push({clubId: id, delta: d, fn: 'worldWeeklyEconomy'});
  }
  const repaid = billing[2].ecritures.find(e => e.title.endsWith('Remboursement du prêt de l’actionnaire')).amount;
  b.debt[2] += repaid; b.prets[2].restant += repaid;
  return {a, b, trace: {writes, debts: [{clubId: 2, delta: repaid, fn: 'pretRembourser'}], billing}};
}
test('A constructed week with billing and an accord reconciles', () => {
  const {a, b, trace} = fixture();
  b.accordsIA.push({id: 'ia-9', vendeurId: 2, acheteurId: 1, montant: 50000});
  b.clubs[1].cash -= 50000; b.clubs[2].cash += 50000;
  trace.writes.push({clubId: 1, delta: -50000, fn: 'calIANouvelAccord'}, {clubId: 2, delta: 50000, fn: 'calIANouvelAccord'});
  const r = reconcile(a, b, trace);
  assert.equal(r.ai.reconciled, 2); assert.equal(r.ai.transferClubs, 2);
  assert.equal(r.ai.loanRepayments, -10000); assert.equal(r.rows.find(x => x.clubId === 2).loan.outstandingAfter, 290000);
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
  f = fixture(); f.b.debt[2] -= 1; f.trace.debts[0].delta -= 1;          // dette qui baisse plus que le remboursement
  assert.equal(reconcile(f.a, f.b, f.trace).rows[2].status, 'unknown');
  f = fixture(); f.b.prets[2].restant += 1;                          // encours du prêt qui ne suit pas
  assert.equal(reconcile(f.a, f.b, f.trace).rows[2].status, 'unknown');
  f = fixture(); f.b.debt[1] += 7; f.trace.debts.push({clubId: 1, delta: 7, fn: 'mystere'}); // dette bougée par un flux inconnu
  assert.deepEqual(reconcile(f.a, f.b, f.trace).rows[1].unknownDebts, [{fn: 'mystere', delta: 7}]);
  f = fixture(); f.b.debt[1] += 7;                                   // dette bougée hors trace
  assert.equal(reconcile(f.a, f.b, f.trace).rows[1].status, 'unknown');
  f = fixture(); f.b.season++;
  assert.throws(() => reconcile(f.a, f.b, f.trace), /no interseason/);
  f = fixture(); f.a.mode = f.b.mode = 'other';
  assert.throws(() => reconcile(f.a, f.b, f.trace), /world-champ/);
});

// Intersaison construite : club joué 1, clubs gérés 0 (clôture simple) et 12 (propriétaire prêteur : l'apport
// devient un prêt). Comptes relevés sur une vraie clôture (graine 4242, fin de saison 1).
const CLOTURE = {
  0: {division: 'elite', compte: {type: 'entreprise', enveloppe: 2700000, depart: 7500000, recettes: 49842300, charges: 47259000, salaires: 10400600, masse: 10400000,
    division: 'elite', rang: 1, taille: 14, reserve: 5050000, investissement: 0, dividende: 0, aideRelegation: 0, base: 86, imprevu: 4192300, fraisMatch: 2096200},
    tresorerie: 10673300, rang: 1, taille: 14, joue: false},
  12: {division: 'elite', compte: {type: 'entreprise', enveloppe: 1500000, depart: 2800000, recettes: 22909200, charges: 25663400, salaires: 9821000, masse: 9822280,
    division: 'elite', rang: 7, taille: 14, reserve: 3160000, investissement: 0, dividende: 0, aideRelegation: 0, base: 72, imprevu: -17300, fraisMatch: 0},
    tresorerie: 747040, rang: 7, taille: 14, joue: false},
};
function interseasonFixture() {
  const clubs = [0, 1, 12].map(id => ({id, cash: CLOTURE[id]?.tresorerie ?? 500000, players: []}));
  const a = {mode: 'world-champ', season: 1, week: 46, phase: 'ended', club: 1, budgetSeason: 1, clubs, ledger: [], accordsIA: [],
    debt: {0: 0, 1: 0, 12: 0}, upgrades: [], dividends: {}, jiff: [], formationFees: [], prets: {}};
  const b = structuredClone(a); Object.assign(b, {season: 2, week: 0, phase: 'league', budgetSeason: 2});
  const trace = {writes: [], debts: [], closing: {}, events: []};
  const write = (clubId, delta, fn) => { b.clubs.find(c => c.id === clubId).cash += delta; trace.writes.push({clubId, delta, fn}); };
  for (const id of [0, 12]) {
    const result = budget.cloture(CLOTURE[id]);
    trace.closing[id] = {args: structuredClone(CLOTURE[id]), result: structuredClone(result)};
    write(id, result.ecritures.reduce((n, e) => n + e.amount, 0), 'budgetCloturer');
  }
  assert.ok(owner.preteur(12, 'entreprise') && trace.closing[12].result.apport > 0, 'fixture: club 12 has a lending owner');
  const granted = owner.accorder(null, trace.closing[12].result.apport, 1, CLOTURE[12].compte.enveloppe);
  b.debt[12] += granted.prete; b.prets[12] = granted.pret; trace.debts.push({clubId: 12, delta: granted.prete, fn: 'pretAccorder'});
  b.upgrades.push({season: 2, id: 0, level: 3, cost: 750000}); write(0, -750000, 'worldNewSeason');
  b.dividends[0] = 400000; write(0, -400000, 'budgetOuvrir');
  trace.events.push({clubId: 12, kind: 'renew', fee: 30000, fn: 'aiRosterContracts'}); write(12, -30000, 'aiRosterContracts');
  b.formationFees.push({season: 2, playerId: 'y', from: 12, to: 0, amount: 90000, contracted: 0}); write(12, -90000, 'settle'); write(0, 90000, 'settle');
  b.jiff.push({season: 1, clubId: 0, league: 'elite', sheets: 26, average: 17.5, deduction: 0, bonus: 250000}); write(0, 250000, 'closeSeason');
  return {a, b, trace};
}
test('A constructed interseason reconciles closing, owner loan, facilities, dividend, renewals, formation fees and JIFF', () => {
  const {a, b, trace} = interseasonFixture(), r = reconcileInterseason(a, b, trace);
  assert.equal(r.ai.reconciled, 2); assert.equal(r.ai.closingReplayed, 2); assert.ok(r.ai.loans > 0);
  assert.equal(r.rows.find(x => x.clubId === 12).loan.lender, true);
  assert.equal(r.rows.find(x => x.clubId === 1).status, 'reconciled-ledger');
});
test('Interseason flows without their own record, or a loan the owner did not grant, stay unknown', () => {
  const cases = {
    'dividend not voted': f => { f.b.dividends[0] = 0; },
    'facility cost not recorded': f => { f.b.upgrades = []; },
    'renewal fee not declared': f => { f.trace.events = []; },
    'formation fee without payment': f => { f.b.formationFees = []; },
    'JIFF without result': f => { f.b.jiff = []; },
    'forged closing': f => { f.trace.closing[0].result.prime++; },
    'loan larger than granted': f => { f.b.debt[12] += 1; f.trace.debts[0].delta += 1; },
    'unknown debt movement': f => { f.b.debt[0] += 5; f.trace.debts.push({clubId: 0, delta: 5, fn: 'mystere'}); },
    'untraced cash': f => { f.b.clubs.find(c => c.id === 0).cash += 1; },
    'cash to debt without the debt': f => { f.b.clubs.find(c => c.id === 12).cash += 1000; f.trace.writes.push({clubId: 12, delta: 1000, fn: 'worldPrepareRenewalLiquidity'}); },
  };
  for (const [name, mutate] of Object.entries(cases)) {
    const f = interseasonFixture(); mutate(f);
    assert.equal(reconcileInterseason(f.a, f.b, f.trace).ai.unknown > 0, true, name);
  }
  const f = interseasonFixture(); f.b.season = 3;
  assert.throws(() => reconcileInterseason(f.a, f.b, f.trace), /exactly one/);
});
test('Reinvested surpluses are replayed as one line per project, same total, only when the club invests this season', () => {
  const args = {forces: [0, 1].map(id => ({id, division: 'champ', base: 60 + id})), clubId: 1, masseHebdo: 40000, semaines: 40, receptions: 12, domicile: false,
    resultats: [], gere: true, repere: '2|1', libelle: '', investissement: 520000, accueil: 1, marge: 0};
  const plain = billingReplay({args, compte: {imprevu: 0, fraisMatch: 0}});
  const split = billingReplay({args, compte: {imprevu: 0, fraisMatch: 0}, invest: {parts: {installations: 0.5, staff: 0.3, accueil: 0.2}}});
  const total = xs => xs.reduce((n, e) => n + e.amount, 0);
  assert.equal(plain.filter(e => / · Investissements \(excédents réinvestis\)$/.test(e.title)).length, 1);
  assert.deepEqual(split.filter(e => e.title.includes('Investissements : ')).map(e => e.title), [' · Investissements : installations', ' · Investissements : staff', ' · Investissements : accueil et billetterie']);
  assert.equal(total(split), total(plain));
});
