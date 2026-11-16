'use strict';
// Préparation (reprise.cjs, décision de Léo du 16/11/2026), éléments « À noter » (façon FM), en carrière Monde
// (`world-champ`, club 0, départ « Reprise des premiers clubs », calendrier journalier comme le jeu) : courrier
// en Réception, arrêt sans réponse attendue selon le flux de Continuer, plusieurs éléments le même jour
// regroupés dans un seul arrêt. Séparé de tests/world-reprise-decisions.cjs (même carrière, mêmes assertions)
// pour rester sous le délai de 180 s du lanceur CI.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');

function carriere(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-presaison-'));
  const b = createBridge({ dataDir: dir, seed: 27, now: 1794178800000, dailyCalendar: true });
  let id = 0;
  const brut = (command, payload = {}) => b.handle({ id: ++id, command, payload });
  const go = (command, payload = {}) => { const r = brut(command, payload); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  t.after(() => { b.close(); fs.rmSync(dir, { recursive: true, force: true }); });
  const etat = () => JSON.parse(go('export').meta.exportText).state;
  const model = settleClubMeetings(go('new_career', { mode: 'world-champ', club: 0, start: 'premiers-clubs' }), go);
  return { brut, go, etat, model, regler: m => settleClubMeetings(m, go) };
}

test('À noter : arrêts informatifs regroupés par jour, Continuer repart sans réponse', { timeout: 1800000 }, t => {
  const j = carriere(t);
  let m = j.model;
  for (const decision of ['amicaux', 'stage']) m = j.go('reprise_decide', { decision, option: 'equilibre' });
  assert.equal(m.meta.continuePlan.kind, 'reprise', 'plus de décision : prochain arrêt, la reprise');
  const arrets = [];
  for (let i = 0; i < 20; i++) {
    m = j.regler(m);
    const r = j.brut('advance_until_event', { fromDate: m.meta.calendarToday, stops: { messages: 'aucun', flux: 'equilibre' } });
    assert.equal(r.ok, true, 'un arrêt informatif n’empêche jamais de repartir : ' + r.error);
    m = r.model;
    const a = m.meta.advanceUntilEvent;
    arrets.push([a.to, a.stop.kind, a.stop.detail]);
    if (a.stop.kind === 'match') break;
    if (a.stop.kind === 'a_noter') assert.equal(m.meta.decisionsDue.length, 0, 'aucune réponse attendue');
  }
  console.log('Arrêts (flux équilibré) :', JSON.stringify(arrets));
  const notes = arrets.filter(x => x[1] === 'a_noter');
  const s = j.etat();
  assert.ok(notes.some(x => x[0] === '2026-08-07' && /bilan du stage/.test(x[2])), 'bilan du stage');
  const amical = notes.find(x => /compte rendu de match amical/.test(x[2]));
  assert.ok(amical, 'compte rendu d’amical');
  // Flux équilibré : le retour des internationaux arrive en Réception sans arrêter l'avance.
  const retour = s.reprise.notes.find(x => x.startsWith('retour:'));
  assert.ok(retour, JSON.stringify(s.reprise.notes));
  assert.ok(!arrets.some(x => x[0] === retour.slice(7)), 'retour sans arrêt en flux équilibré');
  assert.ok(s.news.some(n => /^Match amical 1\/\d : /.test(n)) && s.news.some(n => /^Retour de tournée : \d+ internationa/.test(n)));
  const veille = notes.at(-1);
  assert.equal(veille[0], '2026-09-05', 'veille de la 1re journée');
  assert.match(veille[2], /^2 éléments en Réception : dernier point recrutement, veille de la 1re journée/, 'plusieurs éléments le même jour : un seul arrêt');
  assert.ok(s.news.some(n => /^Dernier point recrutement avant la 1re journée/.test(n)) && s.news.some(n => /^Veille de la 1re journée/.test(n)));
  assert.equal(new Set(notes.map(x => x[0])).size, notes.length, 'un seul arrêt par jour, tous les éléments regroupés');
  assert.equal(arrets.at(-1)[1], 'match');
  // Sauvegarde : éléments déjà envoyés gardés, jamais renvoyés.
  const text = j.go('export').meta.exportText;
  assert.equal(j.brut('import', { text }).ok, true);
  const broken = JSON.parse(text);broken.state.reprise.notes.push('plage:2026-08-01');
  assert.equal(j.brut('import', { text: JSON.stringify(broken) }).ok, false);
});
