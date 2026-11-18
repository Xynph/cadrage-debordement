'use strict';
// Calendrier de presse façon FM (décision de Léo, 18/11/2026) : plus de conférence chaque lundi. Une rentrée la semaine
// du 1er match ; un après-match court (2 ou 3 questions) ouvert dès la validation du résultat, dans un créneau à part ;
// s'il reste sans réponse quand le manager poursuit, Gabi le tient (pas d'arrêt de « Continuer » en plus).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const Monde = require('./helpers/carriere-monde.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

test('Champ Rugby : une seule conférence avant le 1er match, puis un après-match court', { timeout: 400000 }, () => {
  const jeu = Monde.ouvrir();
  try {
    let model = jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs' });
    const conferences = [];
    // Avance jusqu'au jour du 1er match en notant chaque conférence ouverte.
    for (let j = 0; j < 160 && !(model.meta.calendarCadence?.matchReady && model.next); j++) {
      const c = model.clubLife?.press?.conference;
      if (c?.available) conferences.push({ date: model.meta.calendarToday, moment: c.moment?.label || '', n: c.questions.length });
      model = settleClubMeetings(model, jeu.call);
      for (const decision of model?.clubLife?.reprise?.due || []) model = jeu.call('reprise_decide', { decision, option: 'staff' });
      if (model.meta.calendarCadence?.matchReady && model.next) break;
      model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
    }
    assert.ok(model.meta.calendarCadence?.matchReady, 'jour du 1er match atteint');
    assert.equal(conferences.length, 1, 'une seule conférence avant le 1er match : ' + JSON.stringify(conferences));
    assert.match(conferences[0].moment, /Arrivée au club|Conférence de rentrée/);
    const premierMatch = Date.parse(model.meta.calendarToday);
    assert.ok(premierMatch - Date.parse(conferences[0].date) <= 7 * 86400000, 'la rentrée tombe la semaine du 1er match');
    const kinds = (model.clubLife.press.invitations || []).map(i => i.kind);
    assert.ok(!kinds.includes('weekly'), 'plus de conférence de la semaine : ' + kinds);

    // Match délégué jusqu'à la validation du résultat : l'après-match est ouvert tout de suite.
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    const press = model.clubLife.press, apres = press.conference;
    assert.equal(press.context.slot, 'apres', 'créneau après-match');
    assert.ok(apres.available && apres.questions.length >= 2 && apres.questions.length <= 4, 'après-match ouvert : ' + apres.questions.length + ' questions');
    if (!apres.moment) assert.ok(apres.questions.length <= 3, 'après-match ordinaire court');

    // Le manager poursuit sans répondre : Gabi prend l'après-match ordinaire, la journée avance.
    if (!apres.moment) {
      const r = jeu.brut('advance_day', { fromDate: model.meta.calendarToday });
      assert.ok(r.ok, 'avance permise : ' + r.error);
      const last = r.model.clubLife.press.lastOutcome;
      assert.equal(last?.delegated, true, 'après-match tenu par Gabi');
      assert.equal(last.context.slot, 'apres');
    }
  } finally { jeu.fermer(); }
});
