'use strict';
// Indemnités de formation à la sortie du centre (décision de Léo du 12/11/2026).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const { factory } = require('../native/engine/formation-fees.cjs');

function setup(install = false) {
  const h = context(437493);
  h.run(`var CDFormationFees = (${factory.toString()})();${install ? 'CDFormationFees.installHooks();' : ''}`);
  return h;
}

test('Barème : 90 000 € pour un jeune ordinaire, plus pour un fort potentiel, double sous contrat Espoir', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify([[3, 1, 0, 70], [3, 1, 0, 85], [3, 1, 1, 70], [3, 1, 1, 94]].map(CDFormationFees.amountFor))`));
  assert.deepEqual(r, [90000, 180000, 180000, 470000]);
});

test('Un autre club paie le club formateur, le club formateur qui le réengage ne paie rien', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => {
    const p = S.clubs[3].players[0], q = S.clubs[3].players[1];
    p.dev.potential = 70; q.dev.potential = 70;
    CDFormationFees.graduate(S, p, 3); CDFormationFees.graduate(S, q, 3);
    const seller = S.clubs[3].cash, buyer = S.clubs[5].cash;
    const due = CDFormationFees.due(S, p, 5), dueHome = CDFormationFees.due(S, q, 3);
    const paid = CDFormationFees.settle(S, p, 5, false), home = CDFormationFees.settle(S, q, 3, false);
    return JSON.stringify({ due, dueHome, paid, home, sellerGain: S.clubs[3].cash - seller, buyerLoss: buyer - S.clubs[5].cash,
      again: CDFormationFees.due(S, p, 5), payments: S.formationFees.payments.length, validate: CDFormationFees.validate(S) });
  })()`));
  assert.equal(r.due, 90000);
  assert.equal(r.dueHome, 0);
  assert.equal(r.paid, 90000);
  assert.equal(r.home, 0);
  assert.equal(r.sellerGain, 90000);
  assert.equal(r.buyerLoss, 90000);
  assert.equal(r.again, 0, 'Une indemnité n’est payée qu’une fois');
  assert.equal(r.payments, 1);
  assert.equal(r.validate, true);
});

test('Le club joué voit l’indemnité dans la prime et l’ordinateur la paie à la signature', () => {
  const h = setup(true);
  const r = JSON.parse(h.run(`(() => {
    const p = S.clubs[3].players[2], q = S.clubs[3].players[3];
    p.dev.potential = 70; q.dev.potential = 70; p.price = 40000;
    CDFormationFees.graduate(S, p, 3); CDFormationFees.graduate(S, q, 3);
    const base = p.price, fee = contractFee(p, 'recruit'), renew = contractFee(p, 'renew');
    const seller = S.clubs[3].cash, buyer = S.clubs[7].cash;
    aiRosterEvent(7, 'recruit', q, 0);
    return JSON.stringify({ extra: fee - base, renewUnchanged: renew === Math.round(p.salary * 2 / 1000) * 1000,
      sellerGain: S.clubs[3].cash - seller, buyerLoss: buyer - S.clubs[7].cash });
  })()`));
  assert.equal(r.extra, 90000);
  assert.equal(r.renewUnchanged, true);
  assert.equal(r.sellerGain, 90000);
  assert.equal(r.buyerLoss, 90000);
});

test('Fenêtre de deux saisons et validation stricte', () => {
  const h = setup();
  const r = JSON.parse(h.run(`(() => {
    const p = S.clubs[3].players[4]; p.dev.potential = 70;
    CDFormationFees.graduate(S, p, 3);
    S.season += 3;
    return JSON.stringify({ expired: CDFormationFees.due(S, p, 5) });
  })()`));
  assert.equal(r.expired, 0);
  for (const breakage of [
    'S.formationFees.extra = 1',
    '(b => b[Object.keys(b)[0]] = [S.clubs.length, 1, 0, 70])(Object.values(S.formationFees.graduates)[0])',
    'S.formationFees.payments.push({ season: 1, playerId: "x", from: 2, to: 2, amount: 1, contracted: 0 })',
  ]) {
    assert.throws(() => h.run(`(() => { const saved = JSON.parse(JSON.stringify(S.formationFees)); try { ${breakage}; CDFormationFees.validate(S); } finally { S.formationFees = saved; } })()`), /Indemnités de formation/);
  }
});
