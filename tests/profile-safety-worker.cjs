'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {skipMatchTalk}=require('./helpers/scene-match-talks.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { createBridge } = require('../native/engine/worker.cjs');
const { createStore } = require('../native/engine/profile-safety.cjs');
const { refuseSavePublication } = require('./helpers/save-publication-refusal.cjs');
function fixture(t, mode = 'common', club = 0) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-safety-worker-'));
  let bridge = createBridge({ dataDir: root, seed: 312, now: 1700000000000 });
  let sequence = 0;
  t.after(() => { bridge.close(); fs.rmSync(root, { recursive: true, force: true }); });
  const call = (command, payload = {}) => bridge.handle({ id: ++sequence, command, payload });
  const good = (command, payload) => { const result = call(command, payload); assert.equal(result.ok, true, result.error); return result.model; };
  const initial = settleClubMeetings(good('new_career', { mode, club }), good);
  const file = path.join(initial.meta.dataDir, 'donnees.json');
  return { root, file, call, good, restart() { bridge.close(); bridge = createBridge({ dataDir: root, seed: 999, now: 1800000000000 }); } };
}
for (const [mode, first, second] of [['common', 0, 1], ['world', 30, 31]]) {
  test(`${mode} : copie avant remplacement, reprise explicite et RNG/horloge conservés`, t => {
    const f = fixture(t, mode, first);
    const original = fs.readFileSync(f.file);
    const originalEnvelope = JSON.parse(original);
    const originalExport = JSON.parse(f.good('export').meta.exportText);
    const next = f.good('new_career', { mode, club: second });
    const entry = next.meta.profileSafety.entries.find(item => item.reason === 'nouvelle-carriere');
    assert.ok(entry);
    assert.deepEqual(fs.readFileSync(path.join(path.dirname(f.file), 'Copies-securite', entry.id, 'profil.json')), original);
    const current = fs.readFileSync(f.file);
    const rejected = f.call('restore_checkpoint', { id: entry.id });
    assert.equal(rejected.ok, false); assert.match(rejected.error, /Confirmation explicite/);
    assert.deepEqual(fs.readFileSync(f.file), current);
    const restored = f.good('restore_checkpoint', { id: entry.id, confirmed: true });
    assert.equal(restored.club.id, first);
    assert.deepEqual(restored.meta.profileSafetyReceipt, { command: 'restore_checkpoint', id: entry.id });
    assert.equal(JSON.parse(f.good('export').meta.exportText).checksum, originalExport.checksum, 'Même état sportif après reprise');
    const restoredEnvelope = JSON.parse(fs.readFileSync(f.file));
    assert.equal(restoredEnvelope.seed, originalEnvelope.seed);
    assert.equal(restoredEnvelope.clock, originalEnvelope.clock);
    assert.ok(restored.meta.profileSafety.entries.some(item => item.reason === 'restauration'));
    // Later normal writes and restarts cannot rotate a durable checkpoint away.
    f.good('save'); f.restart();
    assert.ok(f.good('snapshot').meta.profileSafety.entries.some(item => item.id === entry.id));
    assert.deepEqual(fs.readFileSync(path.join(path.dirname(f.file), 'Copies-securite', entry.id, 'profil.json')), original);
  });
}
test('import invalide : aucun checkpoint, aucune mutation de fichier/export/RNG/horloge', t => {
  const f = fixture(t);
  const before = fs.readFileSync(f.file);
  const exported = f.good('export').meta.exportText;
  for (const text of ['{', '{}', JSON.stringify({ format: 'cadrage-debordement-save', exportVersion: 999 })]) {
    assert.equal(f.call('import', { text }).ok, false);
    assert.deepEqual(fs.readFileSync(f.file), before);
    assert.equal(f.good('export').meta.exportText, exported);
    assert.deepEqual(f.good('snapshot').meta.profileSafety.entries, []);
    assert.equal(fs.existsSync(path.join(path.dirname(f.file), 'Copies-securite')), false);
  }
});
test('import valide puis refus de publication : rollback bytewise et copie durable réutilisable', t => {
  const f = fixture(t);
  const exported = f.good('export').meta.exportText;
  f.good('set_tactics', { attack: 'conquete', defense: 'equilibre' });
  const before = fs.readFileSync(f.file), priorExport = f.good('export').meta.exportText;
  const result = refuseSavePublication(f.file, () => f.call('import', { text: exported }));
  assert.equal(result.ok, false);
  assert.deepEqual(fs.readFileSync(f.file), before);
  assert.equal(f.good('export').meta.exportText, priorExport);
  const entries = f.good('snapshot').meta.profileSafety.entries;
  assert.equal(entries.filter(entry => entry.reason === 'import').length, 1);
  const imported = f.good('import', { text: exported });
  assert.equal(imported.meta.profileSafety.entries.filter(entry => entry.reason === 'import').length, 1);
});
test('copie altérée et quota plein refusent une restauration/import sans toucher la carrière', t => {
  const f = fixture(t);
  const exported = f.good('export').meta.exportText;
  const next = f.good('new_career', { mode: 'common', club: 1 });
  const entry = next.meta.profileSafety.entries[0];
  const raw = fs.readFileSync(f.file);
  const target = path.join(path.dirname(f.file), 'Copies-securite', entry.id, 'carriere.json');
  fs.appendFileSync(target, 'corruption');
  const failed = f.call('restore_checkpoint', { id: entry.id, confirmed: true });
  assert.equal(failed.ok, false); assert.match(failed.error, /empreinte/);
  assert.deepEqual(fs.readFileSync(f.file), raw);
  const safety = createStore(path.dirname(f.file));
  for (let i = 0; i < 7; i++) {
    const profile = JSON.parse(raw); profile.seed = i;
    safety.checkpoint({ profile: Buffer.from(JSON.stringify(profile)), text: exported, reason: 'import', club: 'Test', season: 1, round: 0 });
  }
  const priorExport = f.good('export').meta.exportText;
  const refused = f.call('import', { text: exported });
  assert.equal(refused.ok, false); assert.match(refused.error, /limite atteinte/);
  assert.deepEqual(fs.readFileSync(f.file), raw);
  assert.equal(f.good('export').meta.exportText, priorExport);
  assert.equal(f.good('snapshot').meta.profileSafety.entries.length, 8);
});
test('A → B → A → B : copie de B cohérente, rollback restauration et action suivante identique au témoin', t => {
  const f = fixture(t);
  const second = settleClubMeetings(f.good('new_career', { mode: 'common', club: 1 }), f.good);
  const copyA = second.meta.profileSafety.entries[0];
  const rawB = fs.readFileSync(f.file);
  const envelopeB = JSON.parse(rawB);
  const afterA = f.good('restore_checkpoint', { id: copyA.id, confirmed: true });
  const copyB = afterA.meta.profileSafety.entries.find(item => item.reason === 'restauration');
  assert.ok(copyB);
  assert.equal(copyB.seed, envelopeB.seed);
  assert.equal(copyB.clock, envelopeB.clock);
  const before = fs.readFileSync(f.file);
  const failed = refuseSavePublication(f.file, () => f.call('restore_checkpoint', { id: copyB.id, confirmed: true }));
  assert.equal(failed.ok, false);
  assert.deepEqual(fs.readFileSync(f.file), before);
  f.good('restore_checkpoint', { id: copyB.id, confirmed: true });
  const resumedB = JSON.parse(fs.readFileSync(f.file));
  assert.equal(resumedB.seed, envelopeB.seed);
  assert.equal(resumedB.clock, envelopeB.clock);
  const witness = path.join(f.root, 'temoin', 'PrototypeGodot');
  fs.mkdirSync(witness, { recursive: true });
  fs.writeFileSync(path.join(witness, 'donnees.json'), rawB);
  const bridge = createBridge({ dataDir: witness, now: 1700000000000 });
  try {
    const result = bridge.handle({ id: 1, command: 'train', payload: { mode: 'intense' } });
    assert.equal(result.ok, true, result.error);
    f.good('train', { mode: 'intense' });
    const reference = bridge.handle({ id: 2, command: 'export' });
    assert.equal(JSON.parse(f.good('export').meta.exportText).checksum, JSON.parse(reference.model.meta.exportText).checksum);
    assert.equal(JSON.parse(fs.readFileSync(f.file)).seed, JSON.parse(fs.readFileSync(path.join(witness, 'donnees.json'))).seed);
  } finally { bridge.close(); }
});
test('adaptation de reprise : profil disque brut préservé, consultation sans écriture', t => {
  const f = fixture(t);
  skipMatchTalk(f.good('begin_match'), f.good);
  const raw = fs.readFileSync(f.file);
  const envelope = JSON.parse(raw);
  assert.equal(JSON.parse(envelope.store['bdt-v1']).live.paused, false);
  f.restart();
  const snapshot = f.good('snapshot');
  assert.equal(snapshot.live.paused, true);
  assert.deepEqual(fs.readFileSync(f.file), raw);
  assert.equal(snapshot.meta.profileSafety.entries.length, 0);
  const saved = f.good('save');
  const copy = saved.meta.profileSafety.entries.find(item => item.reason === 'adaptation-reprise');
  assert.ok(copy);
  assert.deepEqual(fs.readFileSync(path.join(path.dirname(f.file), 'Copies-securite', copy.id, 'profil.json')), raw);
  const replay = f.good('restore_checkpoint', { id: copy.id, confirmed: true });
  assert.equal(replay.live.paused, true, 'La reprise compatible fige le match ; le brut original reste archivé');
});
