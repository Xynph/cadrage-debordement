'use strict';
// Derby (carrière Monde, world-champ, club 5, cadence journalière comme dans le jeu) : calendrier de presse façon FM
// (18/11/2026) : aucune conférence avant un match ordinaire (hors rentrée de la semaine du 1er match). Avant un derby, une
// conférence « Derby » s'ouvre 2 jours avant le match : grand moment (obligatoire, 4 questions, situation « Derby »,
// question d'avant-match nommant le rival). Le même prochain match porte `next.derby` dans la projection envoyée à Godot.
// Rivalités semées par DERBYS (dist/rugby.js) : le club 5 reçoit ou rend visite à son rival (club 4) à la journée 13.
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./helpers/carriere-monde.cjs');

const conf = model => model.clubLife?.press?.conference;

// Joue la saison jour par jour et note, avant tout règlement, chaque conférence ouverte ; s'arrête au premier derby
// (conférence de derby ouverte) ou, à défaut, au jour de son match.
function jusquAuDerby(jeu, model) {
  const ouvertes = [];
  for (let j = 0; j < 400; j++) {
    const c = conf(model);
    if (c?.available && c.moment?.kind === 'derby') return { model, ouvertes };
    if (c?.available && c.questions?.length) ouvertes.push({ date: model.meta.calendarToday, moment: c.moment?.kind || null, kind: (model.clubLife.press.invitations || []).find(i => i.id === c.invitationId)?.kind });
    model = jeu.regler(model);
    if (model.meta.calendarCadence?.matchReady && model.next) {
      assert.ok(!model.next.derby, 'le derby est annoncé par sa conférence avant le jour du match');
      model = M.jouerLeMatch(jeu, model);
      continue;
    }
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'journée autorisée (' + model.meta.calendarToday + ')');
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
  }
  assert.fail('aucun derby en 400 journées');
}

test('Presse : conférence de derby avant un derby, rien avant un match ordinaire', { timeout: 900000 }, () => {
  const jeu = M.ouvrir();
  try {
    let model = jeu.call('new_career', { mode: 'world-champ', club: 5, start: 'premiers-clubs' });
    assert.equal(conf(model).available, false, 'pas de conférence à la création de la carrière');
    const { model: avantDerby, ouvertes } = jusquAuDerby(jeu, model);
    model = avantDerby;
    // Avant le derby : la rentrée (semaine du 1er match), puis seulement des conférences d'événement (recrue, rumeur,
    // affiche non derby) ; jamais de conférence de derby ni de conférence « de la semaine » avant un match ordinaire.
    console.log('conférences ouvertes avant le derby :', JSON.stringify(ouvertes));
    assert.equal(ouvertes.filter(o => o.kind === 'arrival').length, 1, 'une seule rentrée');
    assert.ok(ouvertes.every(o => o.moment !== 'derby' && o.kind !== 'weekly'), 'aucune conférence de derby ou hebdomadaire avant');
    const derby = conf(model), press = model.clubLife.press;
    assert.equal(derby.moment.kind, 'derby');
    assert.match(derby.moment.label, /^Derby face à /);
    assert.equal(derby.required, true, 'conférence de derby en personne');
    assert.equal(derby.situation?.derby, true);
    assert.equal(derby.questions.length, 4, 'grand moment : 4 questions');
    assert.equal(derby.delegation.allowed, false);
    const nom = derby.moment.label.slice('Derby face à '.length);
    assert.ok(derby.questions.some(q => q.theme === 'avant_match' && (q.text || q.question || '').includes(nom)), 'une question cite le rival ' + nom);
    assert.ok(press.invitations.some(i => i.id === derby.invitationId && i.kind === 'prematch'), 'invitation d’avant-match');
    assert.ok(model.next.derby.tension >= 60, 'next.derby projeté (tension)');
  } finally { jeu.fermer(); }
});
