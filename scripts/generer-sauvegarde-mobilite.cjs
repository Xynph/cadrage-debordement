'use strict';
// Génère la sauvegarde « carrière Monde (club 29, graine 13) en fin de saison, fenêtre de mobilité ouverte »
// utilisée par tests/native-manager-career-reverse-*.cjs. Reproductible (graine et horloge fixes).
// Usage : [CD_MOBILITE_DIR=<dossier>] node scripts/generer-sauvegarde-mobilite.cjs [--force]
// Coût : ~850 s et ~2 Go de tas (une saison Monde jouée semaine par semaine) ; no-op si le cache est à jour.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const zlib = require('node:zlib');
const { settleClubMeetings } = require('../tests/helpers/club-meetings.cjs');
const { createBridge } = require('../native/engine/worker.cjs');
const { chemin } = require('../tests/helpers/sauvegarde-mobilite.cjs');

const cible = chemin();
if (fs.existsSync(cible) && !process.argv.includes('--force')) { console.log('Sauvegarde à jour :', cible); process.exit(0); }
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'native-mobilite-gen-'));
const bridge = createBridge({ dataDir: path.join(root, 'saison'), seed: 13, now: 1700000000000 });
let request = 0;
const good = (command, payload = {}) => { const r = bridge.handle({ id: ++request, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
const t0 = Date.now();
try {
  settleClubMeetings(good('new_career', { mode: 'world-champ', club: 29 }), good);
  const data = () => good('snapshot').clubLife.managerCareer;
  good('manager_career_activate', { context: data().context });
  let model = good('snapshot');
  for (let i = 0; i < 80 && !model.clubLife.managerCareer.window; i++) {
    // Le modèle de chaque clôture de semaine sert de lecture suivante (une saison Monde compte plus de quarante semaines).
    if (model.next) {
      if (!model.selection.valid) model = good('auto_lineup');
      if (!model.selection.valid) {
        const expectedSlots = model.selection.coverage?.slots;
        assert.ok(expectedSlots?.length, 'Semaine ' + model.meta.week + ' : feuille incomplète sans renfort disponible');
        model = good('promote_cover', { confirmed: true, expectedSlots });
      }
      assert.equal(model.selection.valid, true, 'Feuille qualifiée avant chaque rencontre de la campagne réelle');
      good('begin_match'); good('delegate');
    }
    model = settleClubMeetings(good('finish_round'), good);
  }
  assert.equal(model.clubLife.managerCareer.window, true, 'La saison s’achève et ouvre la fenêtre de mobilité');
  const text = good('export').meta.exportText;
  fs.mkdirSync(path.dirname(cible), { recursive: true });
  const tmp = cible + '.' + process.pid + '.tmp';
  fs.writeFileSync(tmp, zlib.gzipSync(text, { level: 9 })); fs.renameSync(tmp, cible);
  console.log('Sauvegarde écrite :', cible, '(' + (text.length / 1e6).toFixed(1) + ' Mo, ' + Math.round((Date.now() - t0) / 1000) + ' s)');
} finally { bridge.close(); fs.rmSync(root, { recursive: true, force: true }); }
