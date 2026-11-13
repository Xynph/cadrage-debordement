'use strict';
// Carrière Monde (`world-champ`, seul mode autorisé) pour les tests : mêmes options que le vrai jeu
// (calendrier journalier, presse obligatoire, carrière internationale), mêmes commandes publiques.
// Le calendrier du Monde avance JOUR PAR JOUR (`advance_day`) : le coup d'envoi n'est possible que
// le jour de la rencontre (`meta.calendarCadence.matchReady`), et un match délégué n'est clos
// qu'après la causerie d'après-match ; sans ces gestes le moteur répond « Aucun nouveau match
// disponible » (match encore en cours) ou « rencontre hors calendrier ».
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../../native/engine/worker.cjs');
const { settleClubMeetings } = require('./club-meetings.cjs');
const { skipMatchTalk } = require('./scene-match-talks.cjs');

// `hebdomadaire: true` : cadence de la semaine (sans `dailyCalendar`, comme les autres tests Monde de main) :
// un match = `begin_match`, `delegate`, `finish_round`, la semaine suivante s'ouvre d'elle-même. Plus rapide ;
// le jeu, lui, tourne en cadence journalière (défaut).
function ouvrir(options = {}) {
  const { hebdomadaire, ...autres } = options;
  options = hebdomadaire ? { dailyCalendar: false, mandatoryPress: false, internationalCareer: false, ...autres } : autres;
  const dataDir = options.dataDir || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-monde-'));
  const { dataDir: ignore, ...reste } = options;
  const bridge = createBridge({ dataDir, seed: 4242, now: 1794315600000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true, matchHighlights: 'dynamique', ...reste });
  let id = 0;
  const brut = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const call = (command, payload = {}) => { const r = brut(command, payload); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  const regler = model => settleClubMeetings(model, call);
  return {
    brut, call, regler, dataDir, bridge,
    fermer: () => { try { bridge.close(); } catch (e) { /* déjà fermé */ } if (!options.dataDir) fs.rmSync(dataDir, { recursive: true, force: true }); },
  };
}

// Nouvelle carrière Monde, rendez-vous du jour réglés.
function creer(jeu, club = 102) {
  return jeu.regler(jeu.call('new_career', { mode: 'world-champ', club }));
}

// Avance jour par jour jusqu'au jour du prochain match du manager (`matchReady`).
function jusquAuMatch(jeu, model, garde = 60) {
  if (!model.meta.calendarCadence) { // cadence hebdomadaire : semaine sans match = on la clôt
    for (let w = 0; w < garde; w++) { model = jeu.regler(model); if (model.next) return model; model = jeu.call('finish_round'); }
    assert.fail('aucun match en ' + garde + ' semaines');
  }
  for (let j = 0; j < garde; j++) {
    model = jeu.regler(model);
    if (model.meta.calendarCadence?.matchReady && model.next) return model;
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'journée autorisée (' + model.meta.calendarToday + ')');
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
  }
  assert.fail('aucun jour de match en ' + garde + ' journées');
}

// Joue le match du jour : feuille, coup d'envoi, causeries ignorées, match délégué jusqu'au bout.
// `delegue: false` s'arrête après le coup d'envoi (direct).
function jouerLeMatch(jeu, model, { delegue = true } = {}) {
  if (!model.selection.valid) model = jeu.call('auto_lineup');
  if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
  model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
  if (!delegue) return model;
  model = skipMatchTalk(jeu.call('delegate'), jeu.call);
  if (!model.meta.calendarCadence) return jeu.regler(jeu.call('finish_round'));
  if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
  return jeu.regler(model);
}

// Avance jusqu'à la semaine suivante (clôture de la journée).
function jusquALaSemaineSuivante(jeu, model, garde = 10) {
  if (!model.meta.calendarCadence) return model;
  const semaine = model.meta.week;
  for (let j = 0; j < garde && model.meta.week === semaine; j++) {
    model = jeu.regler(model);
    if (model.meta.week !== semaine) break;
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'clôture quotidienne autorisée');
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
  }
  return jeu.regler(model);
}

// Joue `n` matchs du manager (délégués) ; renvoie le dernier modèle.
function jouer(jeu, model, n) {
  for (let k = 0; k < n; k++) {
    model = jusquAuMatch(jeu, model);
    model = jouerLeMatch(jeu, model);
    model = jusquALaSemaineSuivante(jeu, model);
  }
  return model;
}

module.exports = { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante, jouer };
