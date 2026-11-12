'use strict';
// Parcours complet : saison 1 sans génération, pronostic d'avril, génération du 1er juillet,
// choix du club via la commande native, sauvegarde et réouverture.
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');

test('Génération du 1er juillet · carrière France', t => {
  const dataDir = fs.mkdtempSync(path.join(path.resolve(os.tmpdir()), 'oval-academy-intake-'));
  const options = { dataDir, seed: 827381, now: 1794178800000 };
  let bridge = createBridge(options);
  t.after(() => { bridge.close(); fs.rmSync(dataDir, { recursive: true, force: true }); });
  let id = 0;
  const ask = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const ok = (command, payload) => { const r = ask(command, payload); assert.equal(r.ok, true, `${command}: ${r.error}`); return r.model; };
  const go = (command, payload) => settleClubMeetings(ok(command, payload), ok);
  const state = () => JSON.parse(ok('export').meta.exportText).state;

  let model = go('new_career', { mode: 'common', club: 29 });
  assert.equal(model.clubLife.academyIntake.available, false, 'aucune génération la première saison');
  for (let w = 0; w < 60 && model.meta.phase !== 'ended'; w++) {
    if (model.next) {
      if (!model.selection.valid) { ok('auto_lineup'); if (!ok('snapshot').selection.valid) ok('promote_cover', { confirmed: true }); }
      ok('begin_match'); ok('delegate');
    }
    model = go('finish_round');
  }
  assert.equal(state().academyIntakeForecast, 1, 'le responsable annonce la génération au printemps');
  model = go('next_season', { confirmed: true });
  const view = model.clubLife.academyIntake;
  assert.equal(view.available, true);
  assert.ok(view.players.length >= 12);
  assert.ok(view.players.every(p => Number.isFinite(p.rating) && p.potentialRange && p.potential === null), 'niveau exact, potentiel en fourchette');
  const saved = ok('export').meta.exportText;
  bridge.close();
  bridge = createBridge(options);
  assert.equal(ok('export').meta.exportText, saved);
  ok('import', { text: saved });

  const before = state();
  const crabos = before.development.academy.filter(p => p.age <= 17).length;
  const keep = view.players.slice(0, Math.min(view.players.length, 35 - crabos)).map(p => p.id);
  assert.equal(ask('academy_intake_confirm', { context: view.context, confirmed: false, keep, release: [] }).ok, false);
  model = ok('academy_intake_confirm', { context: view.context, confirmed: true, keep, release: [] });
  assert.equal(model.clubLife.academyIntake.available, false);
  const after = state();
  assert.equal(after.academyIntake, undefined);
  assert.ok(keep.every(pid => after.development.academy.some(p => p.id === pid)));
  assert.ok(model.decisions.development.academy.some(p => p.id === keep[0] && Number.isFinite(p.rating)));
  assert.ok(after.aiRoster.academies.every(c => c.players.filter(p => p.age <= 17).length <= 35 && c.players.length <= 75));
  const text = ok('export').meta.exportText;
  bridge.close();
  bridge = createBridge(options);
  assert.equal(ok('export').meta.exportText, text);
});
