'use strict';
// Finitions critiques (carrière Monde, seul mode autorisé), côté moteur :
//  1. « Continuer » : le prochain arrêt prévisible (continuer.plan) est le match, la reprise ou un rendez-vous en
//     file, le plus proche ; les tranches partielles de la commande le publient (progress.plan).
//  2. Fiche joueur : chaque ligne de l'historique porte l'identifiant de la compétition (competitionId), que
//     l'interface résout en nom lisible du championnat (« Champ Rugby » n'est qu'un nom interne de registre).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const C = require('../native/engine/continuer.cjs');
const Monde = require('./helpers/carriere-monde.cjs');

test('Continuer : prochain arrêt prévisible', () => {
  const base = { today: '2026-09-01', meeting: null, next: { date: '2026-09-11', opponent: 'Rivaux' } };
  assert.deepEqual(C.plan(base), { kind: 'match', date: '2026-09-11', opponent: 'Rivaux' });
  assert.equal(C.plan({ ...base, next: null }), null, 'aucun arrêt prévisible sans rencontre');
  assert.equal(C.plan(base, '2026-09-05').kind, 'reprise', 'la reprise de l’entraînement est plus proche que le match');
  assert.equal(C.plan(base, '2026-09-20').kind, 'match', 'une reprise passée ou plus tardive ne compte pas');
  const rdv = C.plan({ ...base, meeting: { kind: 'medical', id: 'm' } });
  assert.equal(rdv.kind, 'rendez_vous');
  assert.equal(rdv.date, '2026-09-02', 'rendez-vous en file : dès le lendemain');
  assert.equal(rdv.detail, 'Point médical');
  assert.equal(C.plan({ ...base, meeting: { kind: 'press', completed: true } }).kind, 'match', 'rendez-vous achevé ignoré');
  assert.equal(C.plan(null), null);
});

test('Continuer : les tranches partielles publient le prochain arrêt', () => {
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    const model = Monde.creer(jeu, 102);
    const r = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday, budgetMs: 1, partial: true });
    assert.equal(r.ok, true, r.error);
    // Une tranche partielle (budget minimal) : progress.plan ; sinon l'avance s'est arrêtée d'elle-même (modèle complet).
    if (r.progress) {
      assert.ok(r.progress.plan === null || (typeof r.progress.plan.date === 'string' && ['match', 'reprise', 'rendez_vous'].includes(r.progress.plan.kind)), 'plan : ' + JSON.stringify(r.progress.plan));
      if (r.progress.plan) assert.ok(r.progress.plan.date >= r.progress.today, 'le prochain arrêt est devant');
    } else assert.ok(r.model.meta.advanceUntilEvent, 'arrêt direct');
  } finally { jeu.fermer(); }
});

test('Fiche joueur : l’historique expose la compétition (identifiant et libellé)', () => {
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    let model = Monde.jusquAuMatch(jeu, Monde.creer(jeu, 102));
    assert.equal(model.meta.leagueId, 'champ', 'club de Champ Rugby (championnat d’accession anglais)');
    model = Monde.jouerLeMatch(jeu, model);
    model = Monde.jusquAuMatch(jeu, model);
    const joueurs = Object.values(jeu.call('snapshot').clubLife.matchNotes.joueurs).filter(j => j.historique?.length);
    assert.ok(joueurs.length > 0, 'au moins un joueur noté');
    for (const ligne of joueurs.flatMap(j => j.historique)) {
      assert.equal(typeof ligne.competitionId, 'string');
      assert.ok(ligne.competitionId.length > 0);
    }
    assert.ok(joueurs.flatMap(j => j.historique).some(l => l.competitionId === 'champ'), 'match de championnat : champ');
    const ligues = Object.fromEntries(jeu.call('snapshot').leagues.map(l => [l.id, l.name]));
    assert.notEqual(ligues.champ, 'Champ Rugby', 'le modèle expose le nom lisible du championnat : ' + ligues.champ);
  } finally { jeu.fermer(); }
});
