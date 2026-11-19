'use strict';
// Plusieurs carrières enregistrées : rangement, réouverture, suppression confirmée, ancienne sauvegarde unique conservée.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const slots = require('../native/engine/career-slots.cjs');

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-carrieres-'));
try {
  // 1. Fichiers seuls : clés de carrière (dont la reprise avant match) rangées et rendues à l'identique.
  const dir = path.join(temp, 'unitaire', 'PrototypeGodot');
  fs.mkdirSync(dir, { recursive: true });
  const career = JSON.stringify({ club: 0, season: 2026, round: 3, clubs: [{ name: 'Club A' }] });
  const store = { 'bdt-v1': career, 'bdt-matchday-pending': '{"avant":"match"}', 'bdt-reglages': 'x' };
  fs.writeFileSync(path.join(dir, 'donnees.json'), JSON.stringify({ protocol: 1, seed: 7, clock: 1000, store }));
  fs.writeFileSync(path.join(dir, 'donnees-precedentes.json'), 'precedent-A');
  // Ancienne sauvegarde unique : c'est la carrière ouverte, rien à convertir.
  assert.equal(slots.active(dir).club, 'Club A');
  assert.deepEqual(slots.list(dir), []);
  const id = slots.stash(dir);
  let profile = JSON.parse(fs.readFileSync(path.join(dir, 'donnees.json'), 'utf8'));
  assert.deepEqual(profile.store, { 'bdt-reglages': 'x' }, 'réglages gardés, carrière rangée');
  assert.equal(fs.existsSync(path.join(dir, 'donnees-precedentes.json')), false);
  assert.equal(slots.active(dir), null);
  assert.deepEqual(slots.list(dir).map(e => [e.id, e.club, e.season, e.round]), [[id, 'Club A', 2026, 3]]);
  profile.seed = 99; profile.store['bdt-reglages'] = 'y';
  fs.writeFileSync(path.join(dir, 'donnees.json'), JSON.stringify(profile));
  slots.restore(dir, id);
  profile = JSON.parse(fs.readFileSync(path.join(dir, 'donnees.json'), 'utf8'));
  assert.deepEqual(profile.store, { ...store, 'bdt-reglages': 'y' }, 'carrière et reprise avant match rendues, réglages actuels gardés');
  assert.equal(profile.seed, 7);
  assert.equal(fs.readFileSync(path.join(dir, 'donnees-precedentes.json'), 'utf8'), 'precedent-A');
  assert.deepEqual(slots.list(dir), []);
  const id2 = slots.stash(dir);
  assert.throws(() => slots.remove(dir, id2, false), /confirmation/);
  assert.throws(() => slots.remove(dir, '../x', true), /identifiant/);
  slots.remove(dir, id2, true);
  assert.deepEqual(slots.list(dir), []);

  // 2. Moteur réel (protocole stdio de Godot) : deux carrières Monde, bascule, suppression.
  const worker = spawn(process.execPath, ['--max-old-space-size=2048', path.join(__dirname, '../native/engine/worker.cjs'), '--data-dir', path.join(temp, 'moteur')], { stdio: ['pipe', 'pipe', 'inherit'], env: { ...process.env, CD_GODOT_SEED: '1' } });
  let buffer = '', waiting = null, next = 0;
  worker.stdout.on('data', chunk => { buffer += chunk; let end; while ((end = buffer.indexOf('\n')) >= 0) { const line = buffer.slice(0, end); buffer = buffer.slice(end + 1); const done = waiting; waiting = null; done(JSON.parse(line)); } });
  const ask = (command, payload = {}) => new Promise(resolve => { waiting = resolve; worker.stdin.write(JSON.stringify({ id: ++next, command, payload }) + '\n'); });
  const club = response => response.model?.club?.name ?? response.model?.meta?.clubName ?? null;
  (async () => {
    try {
      await ask('snapshot');
      let r = await ask('new_career', { mode: 'world-champ', club: 0 });
      assert.equal(r.ok, true, r.error);
      r = await ask('career_slots', { action: 'list' });
      assert.equal(r.ok, true, r.error);
      const first = r.careerSlots.active.club;
      assert.ok(first && first !== 'Carrière', 'nom du club de la carrière ouverte');
      r = await ask('career_slots', { action: 'new' });
      assert.equal(r.ok, true, r.error);
      assert.equal(r.careerSlots.active, null, 'nouvelle carrière : aucune carrière ouverte');
      assert.equal(r.careerSlots.saved.length, 1);
      r = await ask('new_career', { mode: 'world-champ', club: 1 });
      assert.equal(r.ok, true, r.error);
      r = await ask('career_slots', { action: 'list' });
      const second = r.careerSlots.active.club;
      assert.notEqual(second, first);
      const firstId = r.careerSlots.saved[0].id;
      assert.equal(r.careerSlots.saved[0].club, first);
      r = await ask('career_slots', { action: 'open', id: firstId });
      assert.equal(r.ok, true, r.error);
      assert.ok(r.model, 'modèle complet après réouverture');
      assert.equal(r.careerSlots.active.club, first);
      assert.deepEqual(r.careerSlots.saved.map(e => e.club), [second]);
      r = await ask('career_slots', { action: 'delete', id: r.careerSlots.saved[0].id });
      assert.equal(r.ok, false, 'suppression sans confirmation refusée');
      r = await ask('career_slots', { action: 'delete', id: r.careerSlots.saved[0].id, confirmed: true });
      assert.equal(r.ok, true, r.error);
      assert.deepEqual(r.careerSlots.saved, []);
      r = await ask('snapshot');
      assert.equal(r.ok, true, r.error);
      await ask('shutdown');
      console.log('career-slots : ok');
    } catch (error) { console.error(error); process.exitCode = 1; worker.kill(); }
    finally { fs.rmSync(temp, { recursive: true, force: true }); }
  })();
} catch (error) { fs.rmSync(temp, { recursive: true, force: true }); throw error; }
