'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { createStore, LIMITS } = require('../native/engine/profile-safety.cjs');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-safety-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const store = createStore(root);
  const input = (seed = 3) => ({ profile: Buffer.from(JSON.stringify({ protocol: 1, seed, clock: 1700000000000, store: { 'bdt-v1': '{}' } })), text: '{"format":"test"}', reason: 'import', club: 'Club témoin', season: 2, round: 4 });
  return { root, store, input };
}
test('consultation sans écriture, copie complète, déduplication et réouverture', t => {
  const { root, store, input } = fixture(t);
  assert.deepEqual(store.project().entries, []);
  assert.deepEqual(fs.readdirSync(root), []);
  const first = store.checkpoint(input());
  assert.equal(store.checkpoint(input()).id, first.id);
  assert.equal(createStore(root).load(first.id).text, input().text);
  assert.equal(store.project().entries.length, 1);
  assert.deepEqual(fs.readFileSync(path.join(root, 'Copies-securite', first.id, 'profil.json')), input().profile);
});
test('quota sans suppression silencieuse et libération explicitement confirmée', t => {
  const { store, input } = fixture(t);
  const entries = Array.from({ length: LIMITS.entries }, (_, i) => store.checkpoint(input(i)));
  assert.throws(() => store.checkpoint(input(99)), /limite atteinte/);
  assert.equal(store.project().entries.length, LIMITS.entries);
  assert.throws(() => store.remove(entries[0].id, false), /confirmation explicite/);
  assert.equal(store.load(entries[0].id).seed, 0);
  store.remove(entries[0].id, true);
  assert.equal(store.checkpoint(input(99)).seed, 99);
  assert.equal(store.project().entries.length, LIMITS.entries);
});
test('corruption de chaque fichier refuse la reprise sans toucher les autres copies', t => {
  const { root, store, input } = fixture(t);
  const healthy = store.checkpoint(input(1));
  for (const name of ['profil.json', 'carriere.json', 'copie.json']) {
    const entry = store.checkpoint(input(name.length));
    const target = path.join(root, 'Copies-securite', entry.id, name);
    fs.appendFileSync(target, '\nmodifié');
    assert.throws(() => store.load(entry.id), /copie|Copie/);
    assert.equal(store.load(healthy.id).seed, 1);
    store.remove(entry.id, true);
  }
});
test('chemins clients, symlinks et taille abusive ne sont jamais suivis', t => {
  const { root, store, input } = fixture(t);
  const entry = store.checkpoint(input());
  for (const id of ['../', '/tmp/fichier', entry.id + '/../', null]) {
    assert.throws(() => store.load(id));
    assert.throws(() => store.remove(id, true));
  }
  const target = path.join(root, 'Copies-securite', entry.id, 'carriere.json');
  fs.truncateSync(target, LIMITS.save + 1);
  assert.throws(() => store.load(entry.id), /volumineux/);
  fs.unlinkSync(target);
  const outside = path.join(root, 'hors-copie.json');
  fs.writeFileSync(outside, 'ne pas suivre');
  fs.symlinkSync(outside, target);
  assert.throws(() => store.load(entry.id), /ordinaire/);
  assert.throws(() => store.remove(entry.id, true), /ordinaire/);
  assert.equal(fs.readFileSync(outside, 'utf8'), 'ne pas suivre');
});
test('quota octets inclut les fichiers corrompus ; aucune copie disparue', t => {
  const { root, store, input } = fixture(t);
  const entries = Array.from({ length: 4 }, (_, i) => store.checkpoint(input(i)));
  for (const entry of entries) fs.truncateSync(path.join(root, 'Copies-securite', entry.id, 'profil.json'), 70 * 1024 * 1024);
  assert.throws(() => store.checkpoint(input(99)), /limite atteinte/);
  assert.equal(store.project().entries.length, 4);
});
test('refus disque avant publication : pas de copie incomplète rendue disponible', t => {
  const { root, store, input } = fixture(t);
  const write = fs.fsyncSync;
  fs.fsyncSync = () => { const error = Error('Disque refusé'); error.code = 'ENOSPC'; throw error; };
  try { assert.throws(() => store.checkpoint(input()), /écriture impossible/); }
  finally { fs.fsyncSync = write; }
  assert.equal(store.project().entries.length, 0);
  assert.deepEqual(fs.readdirSync(path.join(root, 'Copies-securite')), []);
  assert.ok(store.checkpoint(input()).id);
});
test('préparation interrompue : visible, comptée, jamais reprise et supprimable explicitement', t => {
  const { root, store, input } = fixture(t);
  const healthy = store.checkpoint(input());
  const id = '.preparation-' + require('node:crypto').randomUUID();
  const pending = path.join(root, 'Copies-securite', id);
  fs.mkdirSync(pending); fs.writeFileSync(path.join(pending, 'profil.json'), 'partiel');
  const state = store.project();
  assert.equal(state.error, '');
  const interrupted = state.entries.find(item => item.id === id);
  assert.equal(interrupted.available, false);
  assert.equal(interrupted.interrupted, true);
  assert.equal(interrupted.bytes, 7);
  assert.throws(() => store.load(id), /indisponible/);
  assert.equal(store.load(healthy.id).seed, 3);
  assert.ok(store.checkpoint(input(9)).id);
  store.remove(id, true);
  assert.equal(fs.existsSync(pending), false);
});
test('une tentative répétée à une autre heure ne consomme pas une nouvelle copie', t => {
  const { store, input } = fixture(t);
  const first = input(); first.text = JSON.stringify({ format: 'test', exportedAt: '2026-11-10T10:00:00.000Z', state: { value: 1 } });
  const original = store.checkpoint(first);
  const second = input(); second.text = JSON.stringify({ format: 'test', exportedAt: '2026-11-10T10:00:10.000Z', state: { value: 1 } });
  assert.equal(store.checkpoint(second).id, original.id);
  assert.equal(store.project().entries.length, 1);
});
