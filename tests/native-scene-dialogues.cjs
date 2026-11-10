'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const target = path.join(__dirname, '../dist/native-scene-dialogues.js');
assert.ok(fs.existsSync(target), 'Portable contextual dialogue bank must exist');
const source = fs.readFileSync(target, 'utf8');
function load(fixture) {
  // Execute the shipped selector against a controlled bank to exercise all condition operators.
  const code = fixture ? source.replace(/\/\* BANK_START \*\/[\s\S]*?\/\* BANK_END \*\//,
    '/* BANK_START */' + JSON.stringify(fixture) + '/* BANK_END */') : source;
  const math = Object.create(Math);
  math.random = () => { throw Error('Dialogue reads must never advance career RNG'); };
  const sandbox = { Math: math };
  vm.runInNewContext(code, sandbox, { filename: target });
  return sandbox.CDSceneDialogues;
}
const bank = load();
const plain = value => JSON.parse(JSON.stringify(value));
const ids = value => plain(value.map(e => e.id));
const all = plain(bank.all());
assert.equal(all.length, 228);
assert.deepEqual(all, JSON.parse(fs.readFileSync(path.join(__dirname, '../native/engine/scene-dialogues-bank.json'), 'utf8')).entries,
  'The portable literal must include the complete reviewable source bank');
assert.equal(new Set(all.map(e => e.id)).size, all.length, 'IDs cannot collide in persisted decisions');
assert.equal(new Set(all.map(e => e.text)).size, all.length, 'Choices must have distinct declarations');
for (const e of all) {
  assert.ok(e.text.length >= 20 && e.text.length <= 120, e.id + ': short, usable declaration');
  assert.ok(!/[�\u0000-\u001f]|\b(?:TODO|TBD|lorem|placeholder)\b/i.test(e.text), e.id + ': valid French content');
  assert.ok(/[.!?]$/.test(e.text), e.id + ': complete sentence');
  assert.ok(e.tone && e.intent, e.id + ': intrinsic emotional intent');
}
for (const phase of ['pre_match', 'half_time', 'post_match', 'team_meeting']) {
  const selected = bank.select(phase, {}, 'fixture:42');
  assert.equal(selected.length, 6, phase + ': six neutral choices');
  assert.ok(selected.every(e => e.phase === phase), phase + ': no cross-phase choice');
  assert.equal(new Set(ids(selected)).size, 6);
  assert.ok(selected.every(e => e.conditions.all.every(tag => tag === 'neutral')));
  assert.ok(new Set(selected.map(e => e.tone)).size >= 4, phase + ': emotional variety');
  assert.ok(new Set(selected.map(e => e.intent)).size >= 4, phase + ': intent variety');
  assert.deepEqual(ids(bank.select(phase, {}, 'fixture:42')), ids(selected));
  const variants = new Set(Array.from({ length: 12 }, (_, i) => JSON.stringify(ids(bank.select(phase, {}, 'fixture:' + i)))));
  assert.ok(variants.size > 1, phase + ': deterministic variation between contexts');
}
for (const [phase, facts, required, forbidden] of [
  ['pre_match', { home: true, away: false }, 'home', 'away'],
  ['half_time', { losing: true, winning: false }, 'losing', 'winning'],
  ['post_match', { result_win: true, result_loss: false }, 'result_win', 'result_loss'],
  ['post_match', { result_loss: true, result_win: false }, 'result_loss', 'result_win']
]) {
  const selected = bank.select(phase, facts, 'real-context');
  assert.equal(selected.length, 6);
  assert.ok(selected.some(e => e.conditions.all.includes(required)), required + ': context takes priority');
  assert.ok(selected.every(e => !e.conditions.all.includes(forbidden)), forbidden + ': never assert false result');
  const reversed = Object.fromEntries(Object.entries(facts).reverse());
  assert.deepEqual(ids(bank.select(phase, reversed, 'real-context')), ids(selected), 'Fact property order is irrelevant');
}
for (const [phase, facts] of [
  ['pre_match', { home: true, away: false }],
  ['pre_match', { away: true, home: false }],
  ['pre_match', { away: true, bad_run: true }],
  ['half_time', { losing: true }],
  ['post_match', { result_win: true }]
]) {
  for (let key = 0; key < 12; key++) {
    const selected = bank.select(phase, facts, 'blend:' + key);
    const neutral = selected.filter(e => e.conditions.all.every(tag => tag === 'neutral') &&
      !e.conditions.any.length && !e.conditions.none.length);
    assert.equal(selected.length, 6);
    assert.equal(neutral.length, 4, phase + ': four general coaching intentions, not six repetitions of context');
    assert.ok(selected.slice(0, 2).every(e => !neutral.includes(e)), 'Two supported contextual choices still take priority');
    assert.ok(new Set(selected.map(e => e.tone)).size >= 4, phase + ': blended emotional variety');
    assert.ok(new Set(selected.map(e => e.intent)).size >= 4, phase + ': blended coaching intent variety');
    assert.deepEqual(ids(bank.select(phase, facts, 'blend:' + key)), ids(selected));
  }
}
assert.deepEqual(ids(bank.select('pre_match', { home: 'true', away: 1, favorite: null }, 'invalid')),
  ids(bank.select('pre_match', {}, 'invalid')), 'Only exact boolean facts authorize claims');
assert.deepEqual(ids(bank.select('pre_match', { tone: 'warm', intent: 'support' }, 'intrinsic')),
  ids(bank.select('pre_match', {}, 'intrinsic')), 'Caller tone/intent cannot filter the six declarations');
const frozenFacts = Object.freeze({ home: true, away: false });
bank.select('pre_match', frozenFacts, 'immutable');
assert.deepEqual(frozenFacts, { home: true, away: false }, 'Selection is a pure read of contextual facts');
assert.equal(bank.select('private_interview', {}, 'invitation').length, 0, 'No invented interview topic');
assert.equal(bank.select('private_interview', { topic_playtime: true }, 'invitation').length, 3);
assert.equal(bank.select('invented_phase', {}, 'x').length, 0);
const fixture = {
  facts: { neutral: { phases: ['pre_match'] }, known: { phases: ['pre_match'] }, wrong_phase: { phases: ['post_match'] } },
  entries: [
    ['all_true', { all: ['known'] }], ['all_false', { all: ['wrong_phase'] }],
    ['any_true', { any: ['known'] }], ['none_false', { none: ['known'] }],
    ['unknown_all', { all: ['missing'] }], ['unknown_any', { any: ['known', 'missing'] }],
    ['unknown_none', { none: ['missing'] }]
  ].map(([id, conditions]) => ({ id, phase: 'pre_match', tone: 'calm', intent: 'focus', text: id,
    conditions: { all: [], any: [], none: [], ...conditions } }))
};
const controlled = load(fixture);
assert.deepEqual(ids(controlled.select('pre_match', { known: true, missing: true, wrong_phase: true }, 'x')).sort(),
  ['all_true', 'any_true'], 'Unknown tags block all, any and none, even if another any tag is true');
assert.deepEqual(ids(controlled.select('pre_match', { known: false }, 'x')), ['none_false']);
assert.equal(controlled.select('pre_match', {}, 'x').length, 0, 'Unknown is not false for a none condition');
assert.equal(controlled.select('pre_match', Object.create({ known: true }), 'x').length, 0, 'Inherited facts have no authority');
const first = bank.all()[0];
first.text = 'Modified'; first.conditions.all.push('invented');
const found = bank.find(first.id);
assert.notEqual(found.text, 'Modified');
assert.ok(!found.conditions.all.includes('invented'));
found.text = 'Modified again';
assert.notEqual(bank.find(first.id).text, 'Modified again');
const selected = bank.select('pre_match', {}, 'copy'); selected[0].text = 'Changed choice';
assert.notEqual(bank.find(selected[0].id).text, 'Changed choice');
assert.equal(bank.find('missing'), null);
assert.deepEqual(plain(require(target).all()), all, 'CommonJS and VM expose the same portable data');
console.log(JSON.stringify({ passed: true, entries: all.length, phases: 5, rngUntouched: true, failClosedConditions: true }));
