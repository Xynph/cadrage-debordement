'use strict';
// Conférence de presse rapide (consolidation du 14/11/2026, calendrier façon FM du 18/11/2026), carrière Monde
// (`world-champ`) démarrée le lundi 13 juillet 2026, presse obligatoire comme dans le jeu. Plus de conférence à la création
// ni chaque lundi : une rentrée s'ouvre le lundi de la semaine du 1er match, puis des conférences d'événement.
//   1. Grand moment (arrivée, atteinte en avançant) : 4 questions, en personne ; l'adjoint est refusé.
//   2. Conférence ordinaire (l'après-match du 1er match, 2 ou 3 questions) : « Envoyer mon adjoint » (press_delegate)
//      répond sur le ton prudent au coût fixe annoncé (médias −2, relation −1 avec chaque journaliste, rien d'autre), archive et reçu.
//   3. Réglage « Conférences ordinaires : envoyer l'adjoint » (press_policy) : l'après-match est tenu par Gabi dès la
//      validation du résultat, « Continuer » ne s'arrête plus dessus, compte rendu de routine en Réception ; avec le
//      réglage « y aller », l'après-match laissé sans réponse est pris par Gabi quand le manager poursuit.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
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

const prudentes = conf => conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === 'cautious').id }));

// Avance avec « Continuer » (décisions de reprise et rendez-vous hors presse réglés) jusqu'à l'ouverture de la
// conférence d'arrivée : le lundi de la semaine du 1er match, jamais à la création de la carrière.
function jusquALArrivee(jeu, model, garde = 40) {
  assert.equal(conferenceOuverte(model), false, 'pas de conférence à la création de la carrière');
  for (let i = 0; i < garde; i++) {
    model = jeu.reglerSaufPresse(model);
    if (conferenceOuverte(model)) return model;
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer: FACULTATIFS } });
  }
  assert.fail('la conférence d’arrivée ne s’ouvre pas');
}
// Arrivée tenue en personne (ton prudent), rendez-vous rangé.
function tenirLArrivee(jeu, model) {
  model = jusquALArrivee(jeu, model);
  const press = model.clubLife.press, conf = press.conference;
  model = jeu.call('press_conference', { context: press.context, invitationId: conf.invitationId, answers: prudentes(conf) });
  return jeu.regler(model);
}
// Grand moment ouvert (crise après trois défaites) : tenu en personne, ton prudent.
function tenirEnPersonne(jeu, model) {
  const press = model.clubLife.press, conf = press.conference;
  model = jeu.call('press_conference', { context: press.context, invitationId: conf.invitationId, answers: prudentes(conf) });
  return jeu.regler(model);
}
// Joue le match du jour (déjà atteint) sans régler l'après-match.
function jouerSansRegler(jeu, model) {
  if (!model.selection.valid) model = jeu.call('auto_lineup');
  model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
  model = skipMatchTalk(jeu.call('delegate'), jeu.call);
  if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
  return model;
}
// Joue le 1er match (ou le suivant) sans régler l'après-match : feuille, coup d'envoi, match délégué, résultat validé.
function jusquAuResultat(jeu, model) {
  return jouerSansRegler(jeu, M.jusquAuMatch(jeu, model));
}

test('Arrivée : grand moment, 4 questions, en personne', { timeout: 900000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    let model = jeu.reglerSaufPresse(jeu.call('snapshot'));
    model = jusquALArrivee(jeu, model);
    const conf = model.clubLife.press.conference;
    assert.equal(conf.available, true, 'la conférence d’arrivée est ouverte');
    assert.equal(conf.moment?.kind, 'arrivee');
    assert.ok(scenePresse(model), 'le rendez-vous de presse est ouvert');
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

test('Conférence ordinaire (après-match) : 3 questions au plus, adjoint au léger coût', { timeout: 1500000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    let model = tenirLArrivee(jeu, jeu.call('snapshot'));
    model = jusquAuResultat(jeu, model);
    const press = model.clubLife.press, conf = press.conference;
    console.log('après-match le', model.meta.calendarToday, ':', conf.questions.length, 'questions, moment', JSON.stringify(conf.moment));
    assert.equal(press.context.slot, 'apres', 'créneau après-match');
    assert.equal(conf.available, true);
    assert.equal(conf.moment, null, 'conférence ordinaire');
    assert.ok(conf.questions.length >= 2 && conf.questions.length <= 3, '3 questions au plus');
    assert.equal(conf.delegation.allowed, true);
    // Coût fixe et annoncé de la délégation (18/11/2026) : médias −2, relation −1 par journaliste, rien d'autre.
    const avant = press.metrics;
    model = jeu.call('press_delegate', { context: press.context, invitationId: conf.invitationId });
    const issue = model.clubLife.press.lastOutcome;
    assert.equal(issue.delegated, true);
    assert.equal(issue.after.mediaTrust, Math.max(0, avant.mediaTrust - 2), 'médias : exactement −2');
    assert.equal(issue.delta.fanTrust, 0, 'supporters inchangés');
    assert.equal(issue.delta.morale, 0, 'moral inchangé');
    for (const e of issue.exchanges) assert.equal(e.delta, e.before > -100 ? -1 : 0, 'relation : exactement −1');
    // Archive : les réponses prudentes de l'après-match, marquées comme tenues par l'adjoint.
    const archives = model.clubLife.press.history.filter(h => h.season === press.context.season && h.week === press.context.week && h.slot === 'apres');
    assert.equal(archives.length, conf.questions.length);
    assert.ok(archives.every(h => h.delegated === true && h.answerId === 'r3'));
    // L'après-match est réglé par la délégation ; « Continuer » range le rendez-vous.
    assert.equal(model.clubLife.press.conference.available, false, 'après-match clos');
    const scene = model.clubLife.clubMeetings.scene;
    if (scene) {
      assert.equal(scene.kind, 'press');
      assert.equal(scene.completed, true);
      model = jeu.call('club_meeting_continue', { meetingId: scene.id });
    }
    assert.equal(model.clubLife.press.conference.available, false, 'conférence close');
  } finally { fermer(); }
});

test('Réglage « envoyer l’adjoint » : Continuer ne s’arrête plus sur l’après-match', { timeout: 2400000 }, () => {
  const { jeu, fermer } = ouvrir();
  try {
    let model = tenirLArrivee(jeu, jeu.call('snapshot'));
    assert.equal(model.clubLife.press.policy.ordinary, 'moi', 'réglage « y aller » par défaut');
    // Réglage « y aller » : l'après-match du 1er match reste à tenir ; si le manager poursuit, Gabi le prend.
    model = jusquAuResultat(jeu, model);
    assert.equal(model.clubLife.press.conference.available, true, 'après-match ouvert avec le réglage « y aller »');
    assert.equal(model.clubLife.press.conference.moment, null);
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'importants', ignorer: FACULTATIFS } });
    assert.ok(model.meta.advanceUntilEvent.pressDelegated >= 1, 'le manager poursuit : Gabi prend l’après-match');
    assert.equal(model.clubLife.press.lastOutcome?.delegated, true);
    // Réglage « envoyer l'adjoint » : l'après-match est tenu par Gabi dès la validation du résultat.
    model = jeu.call('press_policy', { ordinary: 'adjoint' });
    assert.equal(model.clubLife.press.policy.ordinary, 'adjoint');
    let delegues = 0, arretsPresse = 0, jours = 0, matchs = 1, immediats = 0;
    for (let i = 0; i < 40 && matchs < 4; i++) {
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
        // Le match du jour est joué (délégué) : l'après-match est pris par Gabi sans arrêt.
        model = jouerSansRegler(jeu, model);
        matchs++;
        if (model.clubLife.press.conference.available) { // série de défaites : la crise est un grand moment, jamais délégué
          assert.equal(model.clubLife.press.conference.moment?.kind, 'crise', 'seule une crise reste à tenir');
          model = tenirEnPersonne(jeu, model);
        } else {
          assert.equal(model.clubLife.press.context.slot, 'apres');
          assert.equal(model.clubLife.press.lastOutcome?.delegated, true, 'après-match du match ' + matchs + ' tenu par Gabi');
          immediats++;
        }
      }
    }
    // Avec l'adjoint, l'après-match est tenu dès la validation du résultat : l'avance n'a rien à déléguer ni à arrêter.
    console.log('conférences déléguées pendant l’avance :', delegues, '· après-matchs immédiats :', immediats, '· arrêts presse (grands moments) :', arretsPresse, '·', jours, 'jours');
    assert.ok(immediats >= 1, 'au moins un après-match tenu par Gabi dès le résultat');
    const tenues = model.clubLife.press.history.filter(h => h.delegated);
    assert.ok(tenues.length >= 2, 'archives marquées');
    const export_ = jeu.call('export');
    assert.ok(export_.meta.exportText.includes('"pressDelegation"'), 'réglage et délégations sauvegardés');
    assert.ok(export_.meta.exportText.includes('Après-match : Gabi a répondu'), 'compte rendu de Gabi en Réception');
    // Retour au réglage « y aller ».
    model = jeu.call('press_policy', { ordinary: 'moi' });
    assert.equal(model.clubLife.press.policy.ordinary, 'moi');
  } finally { fermer(); }
});
