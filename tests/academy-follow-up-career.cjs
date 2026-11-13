'use strict';
// Suivi du centre dans une vraie carrière : projection native (niveau exact, potentiel en
// fourchette), alertes après les journées, sauvegarde, réouverture et import refusé si altéré.
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');

// Réécrit l'empreinte d'un export modifié (même calcul que dist/saves.js).
function encoded(doc) {
  const text = JSON.stringify(doc.state);
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  doc.checksum = (h >>> 0).toString(16).padStart(8, '0');
  return JSON.stringify(doc);
}

test('Suivi du centre · carrière', t => {
  const dataDir = fs.mkdtempSync(path.join(path.resolve(os.tmpdir()), 'oval-academy-follow-up-'));
  const options = { dataDir, seed: 615616, now: 1794178800000 };
  let bridge = createBridge(options);
  t.after(() => { bridge.close(); fs.rmSync(dataDir, { recursive: true, force: true }); });
  let id = 0;
  const ask = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const ok = (command, payload) => { const r = ask(command, payload); assert.equal(r.ok, true, `${command}: ${r.error}`); return r.model; };
  const go = (command, payload) => settleClubMeetings(ok(command, payload), ok);
  const exported = () => JSON.parse(ok('export').meta.exportText);
  const round = () => {
    const model = ok('snapshot');
    if (model.next) {
      if (!model.selection.valid) { ok('auto_lineup'); if (!ok('snapshot').selection.valid) ok('promote_cover', { confirmed: true }); }
      ok('begin_match'); ok('delegate');
    }
    return go('finish_round');
  };

  let model = go('new_career', { mode: 'world-champ', club: 29 });
  let view = model.clubLife.academyFollowUp;
  assert.equal(view.available, true);
  assert.ok(view.crabos.count > 0 && view.espoirs.count > 0);
  assert.equal(view.crabos.count + view.espoirs.count, view.total);
  assert.equal(view.competitions.available, false, 'pas de résultats de jeunes inventés');
  assert.ok(view.players.every(p => Number.isFinite(p.rating) && p.potential === null && p.potentialRange && p.potentialRange.max >= p.potentialRange.min),
    'niveau exact pour nos jeunes, potentiel en fourchette');
  model = round();
  view = model.clubLife.academyFollowUp;
  assert.equal(view.available, true);

  // Un jeune devient un crack (sauvegarde modifiée puis importée) : l'alerte suit la journée.
  const file = exported();
  const s = file.state;
  assert.equal(s.academyFollowUp.version, 1);
  const target = s.development.academy.find(p => !s.academyFollowUp.cracks.includes(p.id));
  target.dev.potential = 94;
  ok('import', { text: encoded(file) });
  model = round();
  const after = exported().state;
  assert.ok(after.academyFollowUp.cracks.includes(target.id));
  assert.ok(after.news.some(text => text.includes('crack') && text.includes(target.name)), 'alerte crack dans le fil');
  assert.ok(model.clubLife.academyFollowUp.players.find(p => p.id === target.id).crack);

  // Sauvegarde et réouverture identiques.
  const saved = ok('export').meta.exportText;
  bridge.close();
  bridge = createBridge(options);
  assert.equal(ok('export').meta.exportText, saved);

  // Une mémoire d'alertes altérée est refusée à l'import.
  const broken = JSON.parse(saved);
  broken.state.academyFollowUp.cracks.push(broken.state.academyFollowUp.cracks[0]);
  const refused = ask('import', { text: encoded(broken) });
  assert.equal(refused.ok, false);
  assert.match(refused.error, /Suivi du centre/);
  assert.equal(ok('export').meta.exportText, saved);
});
