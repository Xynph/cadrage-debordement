'use strict';
// Reprise d'un ancien journal de sauvegarde (lignes sans `w`, écrites avant #1309) dont un « Continuer » franchit une
// semaine. Dans le jeu, les jours d'un « Continuer » ne sont pas projetés un par un : la séance de la semaine jouée à la
// clôture (trainWeek) lit les séances posées par la dernière projection, celles d'une semaine déjà passée. Une coupure
// pendant ou juste après cette avance, puis « Continuer » au rechargement : la reprise doit retrouver la carrière
// exacte (toutes les actions, sans alerte, export identique), jamais revenir à un état plus ancien.
// Carrière Monde `world-champ` (club 102, graine et horloge du harnais), calendrier journalier, journal d'actions.
if (!process.execArgv.some(a => a.startsWith('--max-old-space-size'))) {
  const r = require('node:child_process').spawnSync(process.execPath, ['--max-old-space-size=2048', ...process.execArgv, __filename, ...process.argv.slice(2)], { stdio: 'inherit' });
  process.exit(r.status ?? 1);
}
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const J = require('../native/engine/action-journal.cjs');
const { STOPS } = require('../native/engine/continuer.cjs');

const dossier = dir => path.join(dir, 'PrototypeGodot');
const lignes = dir => fs.readFileSync(path.join(dossier(dir), J.FILE), 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
const ouvrir = dataDir => M.ouvrir({ dataDir, journal: true, deferredCommits: true });
// Empreinte SHA-256 du texte de l'état exporté (preuve du moteur) : pas de copie de ~22 Mo.
const exporter = jeu => { const p = jeu.call('export', { proof: true }).meta.exportRoundTripSha256; assert.match(p, /^[a-f0-9]{64}$/); return p; };
const lundi = date => { const d = new Date(Date.parse(date)); d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7); return d.toISOString().slice(0, 10); };
// « Continuer » sans arrêt facultatif : la plus longue avance possible, jusqu'au prochain arrêt obligatoire.
const ignorer = Object.keys(STOPS).filter(k => !STOPS[k].mandatory);

let racine;
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

test('Ancien journal : un « Continuer » qui franchit une semaine est repris en entier, carrière identique', { timeout: 1500000 }, () => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-reprise-semaine-'));
  const partie = path.join(racine, 'partie');
  const jeu = ouvrir(partie);
  let coupure, etat, lignesAvance, perimees;
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102 }));
    for (let n = 0; n < 60 && !coupure; n++) {
      if (model.meta.calendarCadence?.matchReady && model.next) { model = M.jouerLeMatch(jeu, model); continue; }
      // Séances prévues par semaine (lundi), vues par la projection d'avant l'avance.
      const prevues = new Set((model.calendarPlanning?.sessions || []).map(s => lundi(s.date)));
      const depart = model.meta.week;
      model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer } });
      const avance = lignes(partie).slice(1).filter(l => l.c === 'advance_day');
      // Jours de cette avance joués avec les séances d'une semaine passée alors que leur semaine en avait au programme.
      const nb = model.meta.advanceUntilEvent?.days || 0, jours = nb ? avance.slice(-nb) : [];
      const ecart = jours.filter(l => l.w && l.w.weekStart !== lundi(l.p.fromDate) && prevues.has(lundi(l.p.fromDate)));
      if (model.meta.week - depart >= 2 && ecart.length) {
        // Disque au moment d'une coupure brutale juste après l'avance (avant la sauvegarde complète qui la suit), puis
        // état en mémoire (l'export passe d'abord par cette sauvegarde complète).
        coupure = path.join(racine, 'coupure');
        fs.cpSync(partie, coupure, { recursive: true });
        fs.rmSync(path.join(dossier(coupure), 'profil.lock'), { force: true });
        etat = exporter(jeu);
        console.log('# avance de ' + jours.length + ' jours jusqu’au ' + model.meta.calendarToday + ', ' + ecart.length + ' avec les séances d’une semaine passée');
        lignesAvance = jours.length; perimees = ecart.length;
        break;
      }
      model = jeu.regler(model);
    }
  } finally { jeu.bridge.close(); }
  assert.ok(coupure, 'un « Continuer » qui franchit deux semaines avec des séances périmées a été trouvé');
  // Ancien format (vraies sauvegardes d'avant #1309) : lignes sans `w`.
  const notees = lignes(coupure);
  assert.ok(notees.length - 1 >= lignesAvance && perimees > 0, 'le journal contient l’avance franchissant la semaine');
  fs.writeFileSync(path.join(dossier(coupure), J.FILE), notees.map(l => { const { w, ...reste } = l; return JSON.stringify(reste) + '\n'; }).join(''));
  const relu = ouvrir(coupure);
  try {
    const notice = relu.call('snapshot').meta.autosave.notice;
    assert.equal(notice.alert, false, 'reprise du journal sans alerte : ' + notice.text);
    assert.equal(notice.replayed, notice.total, 'toutes les actions reprises : ' + notice.text);
    assert.equal(exporter(relu), etat, 'carrière reprise identique à celle d’avant la coupure');
  } finally { relu.bridge.close(); }
});
