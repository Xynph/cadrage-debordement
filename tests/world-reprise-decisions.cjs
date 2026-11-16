'use strict';
// Décisions de la préparation (reprise.cjs, décision de Léo du 16/11/2026) : programme des matchs amicaux
// (dû le jour de la reprise) et orientation du stage (dû une semaine plus tard), en carrière Monde
// (`world-champ`, club 0, départ « Reprise des premiers clubs », calendrier journalier comme le jeu).
//   1. « Continuer » s'arrête le jour dû et refuse de repartir tant que la décision n'est pas prise.
//   2. Choix du manager (rodage à domicile, stage foncier) : recettes, minutes des jeunes, condition, charge
//      et moral appliqués au début de saison, mesurés contre la préparation prudente.
//   3. Délégation : « Jour suivant » au-delà du jour dû confie la décision à Gabi (choix prudent, annoncé),
//      « Confier à Gabi » fait de même ; même graine, même préparation.
//   4. Éléments « À noter » (façon FM) : courrier en Réception, arrêt sans réponse attendue selon le flux de
//      Continuer, plusieurs éléments le même jour regroupés dans un seul arrêt.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const C = require('../native/engine/continuer.cjs');

const FACULTATIFS = Object.keys(C.STOPS).filter(k => !C.STOPS[k].mandatory);
const REPRISE = '2026-07-27', STAGE = '2026-08-03';

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
// Continuer jusqu'au prochain arrêt obligatoire (rendez-vous du club réglés en chemin).
function continuer(j, model, attendu) {
  for (let i = 0; i < 12; i++) {
    model = j.regler(model);
    const r = j.brut('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer: FACULTATIFS } });
    assert.equal(r.ok, true, r.error);
    const a = r.model.meta.advanceUntilEvent;
    if (a.stop.kind === attendu) return r.model;
    assert.ok(['rendez_vous', 'conference', 'ouverture', 'conversation', 'a_noter'].includes(a.stop.kind), 'arrêt inattendu : ' + JSON.stringify(a.stop));
    model = r.model;
  }
  assert.fail('arrêt « ' + attendu + ' » jamais atteint');
}
const decision = (model, key) => model.clubLife.reprise.decisions.find(d => d.key === key);
const bilan = []; // préparations comparées : [choix du manager, délégation]

test('Continuer s’arrête sur chaque décision, le choix du manager a des conséquences mesurables', { timeout: 1800000 }, t => {
  const j = carriere(t);
  let m = j.model;
  assert.equal(m.meta.calendarToday, '2026-07-13');
  const r = m.clubLife.reprise;
  assert.equal(r.club.date, REPRISE);
  assert.deepEqual(r.decisions.map(d => [d.key, d.due, d.pending, d.selected]), [['amicaux', REPRISE, true, null], ['stage', STAGE, true, null]]);
  for (const d of r.decisions) {
    assert.ok(d.options.some(o => o.prudent && o.id === 'equilibre'), 'option prudente du staff');
    assert.ok(d.options.find(o => o.id === d.advice.option), 'Gabi conseille une option proposée');
    assert.ok(d.options.every(o => o.summary.length > 10));
  }
  assert.ok(decision(m, 'amicaux').options.find(o => o.id === 'rodage').receipts > 0, 'recettes du rodage à domicile annoncées');
  assert.ok(decision(m, 'amicaux').options.find(o => o.id === 'releve').receipts < 0, 'frais de l’opposition relevée annoncés');
  assert.deepEqual(m.meta.continuePlan, { kind: 'decision', date: REPRISE, detail: 'Programme des matchs amicaux' }, 'prochain arrêt annoncé');

  // 1. Arrêt le jour de la reprise ; refus de repartir sans décision, sans rien changer.
  m = continuer(j, m, 'decision');
  assert.equal(m.meta.calendarToday, REPRISE);
  assert.match(m.meta.advanceUntilEvent.stop.detail, /programme des matchs amicaux/);
  assert.deepEqual(m.clubLife.reprise.due, ['amicaux']);
  const refus = j.brut('advance_until_event', { fromDate: REPRISE });
  assert.equal(refus.ok, false);
  assert.match(refus.error, /Gabi attend le programme des matchs amicaux/);
  assert.equal(refus.model.meta.calendarToday, REPRISE);
  for (const payload of [{ decision: 'amicaux', option: 'toString' }, { decision: 'inconnue', option: 'rodage' }, { decision: 'amicaux' }, { decision: 'stage', option: 'rodage' }])
    assert.equal(j.brut('reprise_decide', payload).ok, false, JSON.stringify(payload));
  m = j.go('reprise_decide', { decision: 'amicaux', option: 'rodage' });
  assert.equal(decision(m, 'amicaux').selected, 'rodage');

  // 2. Arrêt une semaine plus tard pour le stage.
  m = continuer(j, m, 'decision');
  assert.equal(m.meta.calendarToday, STAGE);
  assert.deepEqual(m.clubLife.reprise.due, ['stage']);
  m = j.go('reprise_decide', { decision: 'stage', option: 'physique' });
  assert.equal(j.brut('reprise_decide', { decision: 'amicaux', option: 'releve' }).ok, false, 'programme arrêté : plus modifiable');

  // 3. Jusqu'à la 1re rencontre : effets appliqués au début de saison.
  m = continuer(j, m, 'match');
  const s = j.etat(), rep = s.reprise.report;
  assert.equal(s.reprise.plan.clubs.find(x => x[0] === 0)[4], 1, 'effets de la préparation appliqués');
  assert.deepEqual(rep.choices, { amicaux: { id: 'rodage', staff: false }, stage: { id: 'physique', staff: false } });
  assert.ok(rep.receipts > 0 && s.ledger.some(l => l.title === 'Recettes des matchs amicaux' && l.amount === rep.receipts), 'recettes au grand livre');
  bilan.push({ effects: rep.effects, youth: Object.fromEntries(rep.youth.map(y => [y.id, y.minutes])), receipts: rep.receipts, morale: s.morale, state: s });
  // Sauvegarde stricte : une option inconnue est refusée à l'import.
  const text = j.go('export').meta.exportText, broken = JSON.parse(text);
  broken.state.reprise.camp = { id: 'plage', staff: false };
  assert.equal(j.brut('import', { text: JSON.stringify(broken) }).ok, false);
  assert.equal(j.brut('import', { text }).ok, true);
});

test('Délégation : Jour suivant et « Confier à Gabi » appliquent le choix prudent', { timeout: 1800000 }, t => {
  const j = carriere(t);
  let m = j.model;
  // Stage confié d'avance à Gabi.
  m = j.go('reprise_decide', { decision: 'stage', option: 'staff' });
  assert.equal(decision(m, 'stage').selected, 'equilibre');
  assert.equal(decision(m, 'stage').staff, true);
  // Programme ignoré : « Jour suivant » jusqu'au lendemain de la reprise.
  for (let i = 0; i < 30 && m.meta.calendarToday <= REPRISE; i++) m = j.go('advance_day', { fromDate: j.regler(m).meta.calendarToday });
  let s = j.etat();
  assert.deepEqual(s.reprise.program, { id: 'equilibre', staff: true }, 'Gabi a arrêté le programme');
  assert.ok(s.news.some(n => /Gabi a arrêté le programme des matchs amicaux à votre place/.test(typeof n === 'string' ? n : n.text || '')), 'délégation annoncée');
  m = continuer(j, m, 'match');
  s = j.etat();
  const rep = s.reprise.report, [choix] = bilan;
  assert.equal(rep.receipts, 0);
  assert.ok(!s.ledger.some(l => /matchs amicaux/.test(l.title)), 'aucune écriture d’amical pour le programme équilibré');
  bilan.push({ effects: rep.effects, youth: Object.fromEntries(rep.youth.map(y => [y.id, y.minutes])) });
  // Conséquences mesurées (même graine, même date de reprise) : rodage + stage foncier contre préparation prudente.
  assert.ok(choix, 'préparation du manager mesurée au test précédent');
  const base = rep.effects, mine = choix.effects;
  assert.equal(mine.conditionGap, Math.max(0, base.conditionGap + 1 - 4), 'stage foncier : condition aux premiers matchs');
  assert.equal(mine.fatigue, base.fatigue + 6, 'stage foncier : charge physique');
  assert.equal(mine.morale, base.morale + 2 - 1, 'rodage +2, foncier −1');
  assert.equal(mine.automatismes, base.automatismes - 1 - 2);
  assert.ok(mine.injuryRisk <= base.injuryRisk);
  const ids = Object.keys(bilan[1].youth).filter(id => id in choix.youth);
  assert.ok(ids.length >= 2, 'mêmes jeunes convoqués par le staff');
  for (const id of ids) assert.ok(choix.youth[id] > bilan[1].youth[id], 'rodage : plus de minutes pour ' + id);
  console.log('Préparation du manager / prudente :', JSON.stringify({ manager: mine, prudent: base, recettes: choix.receipts }));
});

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
