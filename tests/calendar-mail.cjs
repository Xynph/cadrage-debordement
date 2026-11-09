'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const mail = require('../native/engine/calendar-mail.cjs');

const context = { today: '2026-09-01', clubId: 4, season: 1 };
const fixture = (date, id = 'championnat-j3') => ({
  id, date, played: false, home: { id: 4, name: 'Le Club' },
  away: { id: 9, name: 'Adversaire', presentation: { name: 'Adversaire affiché' } }
});

test('une ancienne carrière prend une référence sans courrier rétroactif', () => {
  assert.equal(mail.validate(undefined), true);
  assert.equal(mail.validate(null), true);
  const state = mail.observe([fixture('2026-09-19')], undefined, context);
  assert.equal(mail.validate(state), true);
  assert.deepEqual(mail.project(state), []);
  assert.deepEqual(mail.anchors(state), []);
  assert.deepEqual(mail.observe([fixture('2026-09-19')], state, context), state);
});

test('un changement crée un seul courrier et le recalage est durable et idempotent', () => {
  const previous = mail.observe([fixture('2026-09-19')], null, context);
  const changed = mail.observe([fixture('2026-09-22')], previous, context);
  const [notice] = mail.project(changed);
  assert.equal(notice.status, 'pending');
  assert.equal(notice.opponent, 'Adversaire affiché');
  assert.deepEqual(mail.anchors(changed), [{ fixtureId: notice.fixtureId, date: '2026-09-19' }]);
  assert.deepEqual(mail.observe([fixture('2026-09-22')], changed, context), changed);
  const decision = mail.decide(changed, { id: notice.id, choice: 'recalibrate' });
  assert.deepEqual(decision.change, {
    fixtureId: notice.fixtureId, fromDate: '2026-09-19', toDate: '2026-09-22'
  });
  assert.equal(mail.project(decision.state)[0].status, 'recalibrated');
  assert.deepEqual(mail.anchors(decision.state), []);
  const restored = JSON.parse(JSON.stringify(decision.state));
  assert.equal(mail.validate(restored), true);
  assert.deepEqual(mail.decide(restored, { id: notice.id, choice: 'recalibrate' }), { state: restored, change: null });
  assert.throws(() => mail.decide(restored, { id: notice.id, choice: 'keep' }), /déjà/);
  assert.equal(mail.project(previous).length, 0);
});

test('le maintien de la préparation et les décalages successifs préservent son ancrage', () => {
  const previous = mail.observe([fixture('2026-09-19')], null, context);
  const first = mail.observe([fixture('2026-09-22')], previous, context);
  const kept = mail.decide(first, { id: mail.project(first)[0].id, choice: 'keep' });
  assert.deepEqual(kept.change, {
    fixtureId: 'championnat-j3', fromDate: '2026-09-19', toDate: '2026-09-22'
  });
  assert.deepEqual(mail.anchors(kept.state), [{ fixtureId: 'championnat-j3', date: '2026-09-19' }]);
  const second = mail.observe([fixture('2026-09-25')], kept.state, context);
  const third = mail.observe([fixture('2026-09-28')], second, context);
  const [, stale, current] = mail.project(third);
  assert.equal(stale.status, 'superseded');
  assert.equal(current.fromDate, '2026-09-25');
  assert.equal(current.planFromDate, '2026-09-19');
  assert.throws(() => mail.decide(third, { id: stale.id, choice: 'recalibrate' }), /plus disponible/);
  assert.deepEqual(mail.decide(third, { id: current.id, choice: 'recalibrate' }).change, {
    fixtureId: current.fixtureId, fromDate: '2026-09-19', toDate: '2026-09-28'
  });
});

test('dates manquantes, matchs terminés et saisons successives ne créent pas de faux changement', () => {
  const previous = mail.observe([fixture('2026-09-19'), fixture(null, 'sans-date')], null, context);
  const changed = mail.observe([fixture('2026-09-22'), fixture('2026-09-27', 'sans-date')], previous, context);
  assert.equal(mail.project(changed).length, 1);
  const elapsed = mail.observe([{ ...fixture('2026-09-22'), played: true }], changed, context);
  const [notice] = mail.project(elapsed);
  assert.equal(notice.status, 'expired');
  assert.deepEqual(mail.anchors(elapsed), [{ fixtureId: notice.fixtureId, date: '2026-09-19' }]);
  assert.throws(() => mail.decide(elapsed, { id: notice.id, choice: 'keep' }), /plus disponible/);
  const next = mail.observe([fixture('2027-09-04')], changed, { ...context, today: '2027-09-01', season: 2 });
  assert.deepEqual(mail.project(next).map(message => message.status), ['expired']);
  assert.deepEqual(mail.anchors(next), []);
});

test('la validation refuse un ancrage corrompu ou une décision incohérente', () => {
  const previous = mail.observe([fixture('2026-09-19')], null, context);
  const changed = mail.observe([fixture('2026-09-22')], previous, context);
  const corrupt = JSON.parse(JSON.stringify(changed));
  corrupt.fixtures[0].planDate = '2026-02-31';
  assert.equal(mail.validate(corrupt), false);
  assert.throws(() => mail.decide(changed, { id: mail.project(changed)[0].id, choice: 'invalid' }), /invalide/);
});
