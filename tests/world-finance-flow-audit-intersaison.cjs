'use strict';
// Audit des flux financiers sur une saison Monde entière (world-champ, budget de saison réaliste), la commande
// « Saison suivante » et le début de la saison 2 (graine 4242, club 102). Chaque semaine : facturation rejouée
// avec le barème de production, indemnités des accords entre clubs. Intersaison : clôture des comptes rejouée
// (prime de classement, amende, apport du propriétaire), prêt de l'actionnaire, installations achetées,
// dividendes, renouvellements et recrutements, indemnités de formation, fonds JIFF ; la dette est tracée
// comme la caisse. Saison 2 : investissements des excédents découpés par chantier.
const {test} = require('node:test'), assert = require('node:assert/strict');
const {run} = require('../ci/world-finance-flow-audit.cjs');

const r = run({seed: 4242, club: 102, interseason: true, weeks: 3});

test('Every managed club reconciles to the euro over a whole season and the start of the next', () => {
  assert.equal(r.passed, true);
  assert.deepEqual([...new Set(r.weeks.map(w => w.season))], [1, 2]);
  assert.equal(r.weeks.filter(w => w.season === 2).length, 3);
  assert.ok(r.weeks.filter(w => w.season === 1).length >= 40, 'the whole first season is audited');
  for (const w of r.weeks) {
    assert.equal(w.ai.reconciled, w.ai.clubs, 'season ' + w.season + ' week ' + w.week + ': ' + JSON.stringify(w.rows.filter(x => x.status === 'unknown').slice(0, 2)));
    assert.equal(w.ai.billingMatched, w.ai.clubs); assert.equal(w.ai.residual, 0); assert.equal(w.ai.transferNet, 0);
    assert.equal(w.rows.find(x => x.kind === 'human-ledger').status, 'reconciled-ledger');
  }
  assert.ok(r.weeks.some(w => w.accords.length), 'accords between managed clubs are audited');
  assert.ok(r.weeks.filter(w => w.season === 2).some(w => w.rows.some(x => x.kind === 'ai' && x.billing.components.some(e => e.title.includes(' · Investissements : ')))),
    'reinvested surpluses split by project are audited in season 2');
});

test('The season change reconciles every managed club: closing, loans, facilities, dividends, contracts, formation fees, JIFF', () => {
  const s = r.interseason, f = s.ai.flows;
  assert.equal(s.ai.reconciled, s.ai.clubs, JSON.stringify(s.rows.filter(x => x.status === 'unknown').slice(0, 2)));
  assert.equal(s.ai.unknown, 0); assert.equal(s.ai.residual, 0); assert.equal(s.ai.closingReplayed, s.ai.clubs);
  for (const row of s.rows.filter(x => x.kind === 'ai')) { assert.equal(row.conserved, true); assert.equal(row.debtConserved, true); }
  assert.equal(s.rows.find(x => x.kind === 'human-ledger').status, 'reconciled-ledger');
  // Chaque flux est réellement exercé par cette bascule (sinon le test ne prouverait rien sur lui).
  assert.ok(f.budgetCloturer > 0, 'league prizes and owner contributions');
  assert.ok(s.ai.loans > 0, 'owner contributions turned into loans');
  assert.ok(f.worldNewSeason < 0 && s.upgrades > 0, 'facility levels bought');
  assert.ok(f.budgetOuvrir < 0, 'dividends paid to shareholder groups');
  assert.ok(f.aiRosterContracts < 0 && f.aiRosterRecruitmentWeek < 0, 'renewal and recruitment fees');
  assert.ok(s.formationFees > 0 && f.settle === 0, 'formation fees move cash between clubs');
  assert.ok(s.jiff > 0 && f.closeSeason !== 0, 'JIFF fund and EQP fines');
});
