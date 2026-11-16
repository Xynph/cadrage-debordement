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
  // Arrêts informatifs de la saison coupés (`ignorer: ['info']`) : le match ; sinon la veille du match l'annonce.
  assert.deepEqual(C.plan(base, null, ['info']), { kind: 'match', date: '2026-09-11', opponent: 'Rivaux' });
  assert.deepEqual(C.plan(base), { kind: 'info', date: '2026-09-10', detail: 'veille du match contre Rivaux' });
  assert.equal(C.plan({ ...base, next: null }), null, 'aucun arrêt prévisible sans rencontre');
  assert.equal(C.plan(base, '2026-09-05').kind, 'reprise', 'la reprise de l’entraînement est plus proche que le match');
  assert.equal(C.plan(base, '2026-09-20', ['info']).kind, 'match', 'une reprise passée ou plus tardive ne compte pas');
  const rdv = C.plan({ ...base, meeting: { kind: 'medical', id: 'm' } });
  assert.equal(rdv.kind, 'rendez_vous');
  assert.equal(rdv.date, '2026-09-02', 'rendez-vous en file : dès le lendemain');
  assert.equal(rdv.detail, 'Point médical');
  assert.equal(C.plan({ ...base, meeting: { kind: 'press', completed: true } }, null, ['info']).kind, 'match', 'rendez-vous achevé ignoré');
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
      assert.ok(r.progress.plan === null || (typeof r.progress.plan.date === 'string' && ['match', 'reprise', 'rendez_vous', 'decision', 'a_noter', 'info'].includes(r.progress.plan.kind)), 'plan : ' + JSON.stringify(r.progress.plan));
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

test('Espoirs appelés : note au poste cohérente avec le niveau ; inscrit sans jouer = petite expérience', () => {
  const PILIER_GAUCHE_MANQUANT = `(()=>{const c=S.clubs[S.club],starter=S.lineup[0];for(const p of c.players)if(p.id!==starter&&(p.pos==='Pilier gauche'||p.nationaleQualifications?.includes('Pilier gauche')))p.injury=3;S.reserves[1]=null;S.trained=true;})()`;
  const run = (jeu, code) => JSON.parse(jeu.bridge.vm.run(`JSON.stringify(${code})`));
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    let model = Monde.jusquAuMatch(jeu, Monde.creer(jeu, 90));
    jeu.bridge.vm.run(PILIER_GAUCHE_MANQUANT);
    model = jeu.call('snapshot');
    const place = model.selection.espoirs.slots[0];
    assert.ok(place.candidates.length > 0);
    // (a) Pilier de son poste naturel : la note au poste proposée est son niveau, pas une note gonflée par ses qualités.
    for (const c of place.candidates.filter(x => x.pos === 'Pilier gauche')) assert.ok(Math.abs(c.note - c.rating) <= 3, `note au poste ${c.note} pour un niveau ${c.rating}`);
    const kid = place.proposedId;
    model = jeu.call('auto_lineup');
    const appele = run(jeu, `(()=>{const p=S.clubs[S.club].players.find(x=>x.id===${JSON.stringify(kid)});return {rating:p.rating,role:roleNote(p),apt:nativePositionAptitudes.rating(p,16)};})()`);
    assert.ok(Math.abs(appele.role - appele.rating) <= 1 && Math.abs(appele.apt - appele.rating) <= 3, 'appelé : ses qualités rejoignent son niveau : ' + JSON.stringify(appele));
    const projete = model.squad.find(p => p.id === kid);
    assert.ok(projete && Math.abs(projete.positionRatings['1'] - projete.rating) <= 3, 'la note au poste affichée partout est celle de l’offre : ' + JSON.stringify(projete?.positionRatings));
    // (b) Récompense : inscrit sur la feuille sans entrer < joue ; hors feuille : rien.
    const total = `(()=>{const p=S.clubs[S.club].players.find(x=>x.id===${JSON.stringify(kid)});return p.rating+(p.dev?.xp||0);})()`;
    const feuille = (minutes, on, bench) => `(()=>{nativeSystems.domain('espoirsMatch').rewardOwn(S,{pair:[S.club,1],userSide:0,sheets:[{minutes:${JSON.stringify(minutes)},on:${JSON.stringify(on)},bench:${JSON.stringify(bench)},used:[]},{minutes:{},on:[],bench:[],used:[]}]});return true;})()`;
    const t0 = run(jeu, total);
    run(jeu, feuille({}, [], []));
    assert.equal(run(jeu, total), t0, 'hors feuille : aucune expérience');
    run(jeu, feuille({}, [], [kid]));
    const t1 = run(jeu, total);
    assert.ok(t1 > t0, 'inscrit sans jouer : une petite expérience');
    run(jeu, feuille({ [kid]: 60 }, [], [kid]));
    const t2 = run(jeu, total);
    assert.ok(t2 - t1 > t1 - t0, `jouer rapporte plus qu’être inscrit (${(t2 - t1).toFixed(3)} contre ${(t1 - t0).toFixed(3)})`);
  } finally { jeu.fermer(); }
});
