'use strict';
// Conférence de presse rapide (consolidation du 14/11/2026, façon FM), carrière Monde (`world-champ`) démarrée le
// lundi 13 juillet 2026, presse obligatoire comme dans le jeu :
//   1. Grand moment (arrivée) : 4 questions, en personne ; l'adjoint est refusé.
//   2. Conférence ordinaire : 3 questions au plus ; « Envoyer mon adjoint » (press_delegate) répond sur le ton
//      prudent avec un léger coût (médias −2, relation −1 avec chaque journaliste), archive et reçu de rendez-vous.
//   3. Réglage « Conférences ordinaires : envoyer l'adjoint » (press_policy) : « Continuer » ne s'arrête plus sur
//      une conférence ordinaire, Gabi la tient dans le moteur et laisse un compte rendu de routine.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const C = require('../native/engine/continuer.cjs');

const FACULTATIFS = Object.keys(C.STOPS).filter(k => !C.STOPS[k].mandatory);
let racine, origine;

before(() => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-presse-rapide-'));
  origine = path.join(racine, 'origine');
  const jeu = M.ouvrir({ dataDir: origine });
  try {
    jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs' });
    jeu.call('save');
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

let copies = 0;
function ouvrir() {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true });
  return { jeu, fermer: () => { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); } };
}
const conferenceOuverte = model => model.clubLife?.press?.conference?.available === true;
const scenePresse = model => model.clubLife?.clubMeetings?.scene?.kind === 'press';

// Règle les rendez-vous autres que la presse, puis avance avec « Continuer » jusqu'à une conférence ouverte.
function jusquALaConference(jeu, model, garde = 12) {
  for (let i = 0; i < garde; i++) {
    if (conferenceOuverte(model)) return model;
    if (model.clubLife?.clubMeetings?.scene) model = jeu.regler(model);
    if (conferenceOuverte(model)) return model;
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer: FACULTATIFS } });
  }
  assert.fail('aucune conférence ouverte');
}

test('Arrivée : grand moment, 4 questions, en personne', { timeout: 900000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    const model = jeu.call('snapshot');
    const conf = model.clubLife.press.conference;
    assert.equal(conf.available, true, 'la conférence d’arrivée est ouverte');
    assert.equal(conf.moment?.kind, 'arrivee');
    assert.equal(conf.questions.length, 4, 'un grand moment garde 4 questions');
    assert.equal(conf.delegation.allowed, false);
    assert.match(conf.delegation.reason, /Arrivée au club/);
    const refus = jeu.brut('press_delegate', { context: model.clubLife.press.context, invitationId: conf.invitationId });
    assert.equal(refus.ok, false);
    assert.match(refus.error, /en personne/);
    // Chaque réponse annonce son ton et ses effets (moral, médias, relation).
    for (const q of conf.questions) for (const a of q.answers) {
      assert.ok(a.toneLabel && a.effects && Number.isFinite(a.effects.relation), 'ton et effets visibles');
    }
  } finally { fermer(); }
});

test('Conférence ordinaire : 3 questions au plus, adjoint au léger coût', { timeout: 1500000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    let model = jeu.regler(jeu.call('snapshot'));
    model = jusquALaConference(jeu, model);
    const press = model.clubLife.press, conf = press.conference;
    console.log('conférence ordinaire le', model.meta.calendarToday, ':', conf.questions.length, 'questions, moment', JSON.stringify(conf.moment));
    assert.equal(conf.moment, null, 'conférence ordinaire');
    assert.ok(conf.questions.length >= 2 && conf.questions.length <= 3, '3 questions au plus');
    assert.equal(conf.delegation.allowed, true);
    assert.ok(scenePresse(model), 'le rendez-vous de presse est ouvert');
    // Effets attendus du ton prudent (aperçu) puis coût de la délégation.
    const prudentes = conf.questions.map(q => q.answers.find(a => a.tone === 'cautious'));
    const medias = prudentes.reduce((n, a) => n + a.effects.media, 0);
    const avant = press.metrics;
    model = jeu.call('press_delegate', { context: press.context, invitationId: conf.invitationId });
    const issue = model.clubLife.press.lastOutcome;
    assert.equal(issue.delegated, true);
    const attendu = Math.max(0, Math.min(100, avant.mediaTrust + medias)) - 2;
    assert.equal(issue.after.mediaTrust, Math.max(0, attendu), 'médias : effet prudent puis −2');
    for (const e of issue.exchanges) {
      const q = conf.questions.find(q => q.journalist.id === e.journalistId);
      const prudent = q.answers.find(a => a.tone === 'cautious');
      const fois = conf.questions.filter(x => x.journalist.id === e.journalistId).length;
      if (fois === 1) assert.equal(e.delta, prudent.effects.relation - 1, 'relation : effet prudent puis −1');
    }
    // Archive : les réponses prudentes, marquées comme tenues par l'adjoint.
    const archives = model.clubLife.press.history.filter(h => h.season === press.context.season && h.week === press.context.week);
    assert.equal(archives.length, conf.questions.length);
    assert.ok(archives.every(h => h.delegated === true && h.answerId === 'r3'));
    // Le rendez-vous est réglé par la délégation ; « Continuer » le range.
    const scene = model.clubLife.clubMeetings.scene;
    assert.equal(scene.kind, 'press');
    assert.equal(scene.completed, true);
    model = jeu.call('club_meeting_continue', { meetingId: scene.id });
    assert.equal(model.clubLife.press.conference.available, false, 'conférence close pour la semaine');
  } finally { fermer(); }
});

test('Réglage « envoyer l’adjoint » : Continuer ne s’arrête plus sur une conférence ordinaire', { timeout: 2400000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    let model = jeu.regler(jeu.call('snapshot'));
    model = jeu.call('press_policy', { ordinary: 'adjoint' });
    assert.equal(model.clubLife.press.policy.ordinary, 'adjoint');
    let delegues = 0, arretsPresse = 0, jours = 0;
    for (let i = 0; i < 14 && delegues < 2; i++) {
      model = jeu.regler(model);
      model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'importants', ignorer: FACULTATIFS } });
      const a = model.meta.advanceUntilEvent;
      jours += a.days;
      delegues += a.pressDelegated;
      if (a.stop.kind === 'conference' || (a.stop.kind === 'rendez_vous' && a.stop.meeting === 'press')) {
        arretsPresse++;
        assert.ok(model.clubLife.press.conference.moment, 'seul un grand moment arrête l’avance : ' + JSON.stringify(a.stop));
      }
      if (a.stop.kind === 'match') {
        // Le match du jour est joué (délégué) pour laisser passer les semaines.
        model = M.jouerLeMatch(jeu, model);
      }
    }
    console.log('conférences tenues par Gabi :', delegues, '· arrêts presse (grands moments) :', arretsPresse, '·', jours, 'jours');
    assert.ok(delegues >= 1, 'au moins une conférence ordinaire tenue par l’adjoint sans arrêt');
    const tenues = model.clubLife.press.history.filter(h => h.delegated);
    assert.ok(tenues.length >= 2, 'archives marquées');
    const reçus = model.clubLife.clubMeetings.receipts.filter(r => r.kind === 'press' && r.decision?.command === 'press_delegate');
    assert.ok(reçus.length >= 1, 'reçu du rendez-vous de presse');
    const export_ = jeu.call('export');
    assert.ok(export_.meta.exportText.includes('"pressDelegation"'), 'réglage et délégations sauvegardés');
    assert.ok(export_.meta.exportText.includes('Conférence tenue par Gabi'), 'compte rendu de Gabi en Réception');
    // Retour au réglage « y aller » : la conférence ordinaire suivante arrête de nouveau l’avance.
    model = jeu.call('press_policy', { ordinary: 'moi' });
    assert.equal(model.clubLife.press.policy.ordinary, 'moi');
  } finally { fermer(); }
});
