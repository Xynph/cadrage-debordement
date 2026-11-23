'use strict';
// Contrats en un coup d'œil (revue FM27, idée 12 ; décision de Léo du 23/11/2026) :
//  - rôle promis au contrat (native/engine/role-contrat.cjs) : titulaire / rotation / espoir / appoint, enregistré à la
//    signature et à la prolongation, déduit de la hiérarchie pour les anciens contrats (migration des sauvegardes) ;
//  - conseil du staff toute l'année (native/engine/prolongations-staff.cjs, conseiller) : prolonger, partir, vendre,
//    vente, garder ; envoyés à l'écran (squad[].roleContrat, squad[].conseilStaff).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory } = require('../native/engine/role-contrat.cjs');
const P = require('../native/engine/prolongations-staff.cjs');

const R = factory();

test('Rôle déduit de la hiérarchie : places du XV par famille de poste, puis rotation, espoir (≤ 21 ans) ou appoint', () => {
  // Centres : famille 7, deux places dans le XV.
  const centres = [90, 85, 80, 75, 70, 65].map((rating, i) => ({ id: 'c' + i, fam: 7, rating, age: i === 4 ? 20 : 27, contractEnd: 2 }));
  assert.deepEqual(centres.map(p => R.deduire(p, centres)), ['titulaire', 'titulaire', 'rotation', 'rotation', 'espoir', 'appoint']);
  // Talonneur : une seule place.
  const talons = [{ id: 't1', fam: 1, rating: 70, age: 30, contractEnd: 1 }, { id: 't2', fam: 1, rating: 72, age: 30, contractEnd: 1 }, { id: 't3', fam: 1, rating: 60, age: 19, contractEnd: 1 }];
  assert.deepEqual(talons.map(p => R.deduire(p, talons)), ['rotation', 'titulaire', 'espoir']);
  // Troisièmes lignes : trois places (6, 7 et 8).
  const troisiemes = [80, 79, 78, 77].map((rating, i) => ({ id: 'f' + i, fam: 3, rating, age: 25, contractEnd: 1 }));
  assert.deepEqual(troisiemes.map(p => R.deduire(p, troisiemes)), ['titulaire', 'titulaire', 'titulaire', 'rotation']);
});

test('Enregistrement : migration d’une ancienne sauvegarde, rôle rattaché au contrat en cours, promesse explicite gardée', () => {
  const joueurs = [
    { id: 'a', fam: 7, rating: 80, age: 26, contractEnd: 3 },
    { id: 'b', fam: 7, rating: 70, age: 26, contractEnd: 2 },
    { id: 'c', fam: 7, rating: 60, age: 26, contractEnd: 1 },
    { id: 'd', fam: 7, rating: 50, age: 20, contractEnd: 1 },
    { id: 'e', fam: 7, rating: 40, age: 25, contractEnd: 1 },
    { id: 'f', fam: 7, rating: 30, age: 19, contractEnd: 1 },
    { id: 'pret', fam: 7, rating: 90, age: 18, contractEnd: 1, espoirLoan: true },
    { id: 'sans', fam: 7, rating: 90, age: 18, contractEnd: null },
  ];
  const s = { season: 1, club: 0, clubs: [{ id: 0, players: joueurs }, { id: 1, players: [{ id: 'x', fam: 7, rating: 99, contractEnd: 2 }] }] };
  assert.equal(R.observe(s), 6, 'six contrats professionnels du club du manager (ni l’appelé du centre ni le joueur sans contrat)');
  assert.deepEqual(joueurs.map(p => p.roleContrat?.role ?? null), ['titulaire', 'titulaire', 'rotation', 'rotation', 'appoint', 'espoir', null, null]);
  assert.deepEqual(joueurs[0].roleContrat, { role: 'titulaire', saison: 1, fin: 3, club: 0, deduit: true });
  assert.equal(s.clubs[1].players[0].roleContrat, undefined, 'les autres clubs ne sont pas touchés');
  assert.equal(R.observe(s), 0, 'déjà enregistrés');
  // Le rôle reste celui du contrat même si la hiérarchie change.
  joueurs[2].rating = 95;
  assert.equal(R.observe(s), 0);
  assert.equal(R.vue(joueurs[2], s).role, 'rotation');
  // Nouveau contrat (prolongation) : nouveau rôle, selon la hiérarchie de ce jour-là.
  joueurs[2].contractEnd = 3; s.season = 2;
  assert.equal(R.observe(s), 1);
  assert.deepEqual(joueurs[2].roleContrat, { role: 'titulaire', saison: 2, fin: 3, club: 0, deduit: true });
  // Promesse explicite (recruit / extend_contract avec `role`) : pas de marque « déduit », gardée par observe.
  assert.equal(R.poser(joueurs[4], 'rotation', false, s), true);
  assert.equal(R.observe(s), 0);
  assert.deepEqual(R.vue(joueurs[4], s), { role: 'rotation', deduit: false, saison: 2 });
  assert.equal(R.poser(joueurs[4], 'capitaine', false, s), false, 'rôle inconnu refusé');
  assert.equal(R.vue(joueurs[6], s), null, 'appelé du centre de formation : pas de contrat, pas de rôle');
  // Vue avant enregistrement : déduite en direct.
  const nouveau = { id: 'n', fam: 7, rating: 99, age: 24, contractEnd: 3 };
  joueurs.push(nouveau);
  assert.deepEqual(R.vue(nouveau, s), { role: 'titulaire', deduit: true, saison: null });
  // Validation de la sauvegarde.
  assert.equal(R.validate(s), true);
  joueurs[0].roleContrat = { role: 'star', saison: 1, fin: 3, club: 0 };
  assert.throws(() => R.validate(s), /Rôle promis/);
});

test('Conseil du staff : prolonger, partir, vendre, vente, garder selon l’échéance, le niveau, l’âge et le salaire', () => {
  const x = { base: 70, effectif: 36, consigne: 'equilibre' };
  const c = o => P.conseiller({ estime: 70, potentiel: 70, age: 27, reste: 2, possibles: 3, profondeur: 4, part: 1 / 36, vente: false, decision: null, ...o }, x);
  // Fin cette saison.
  assert.deepEqual(c({ reste: 0 }), { conseil: 'prolonger', raison: 'cadre' });
  assert.deepEqual(c({ reste: 0, age: 21, estime: 66, potentiel: 78 }), { conseil: 'prolonger', raison: 'jeune' });
  assert.deepEqual(c({ reste: 0, estime: 60, profondeur: 1 }), { conseil: 'prolonger', raison: 'profondeur' });
  assert.deepEqual(c({ reste: 0, estime: 60 }), { conseil: 'partir', raison: 'niveau' });
  assert.deepEqual(c({ reste: 0, possibles: 0 }), { conseil: 'partir', raison: 'retraite' });
  assert.deepEqual(c({ reste: 0, decision: 'libere' }), { conseil: 'partir', raison: 'decide' });
  // Dernière année la saison prochaine : jeunes prometteurs et cadres verrouillés tôt.
  assert.deepEqual(c({ reste: 1, age: 22, estime: 62, potentiel: 75 }), { conseil: 'prolonger', raison: 'jeune' });
  assert.deepEqual(c({ reste: 1, estime: 76 }), { conseil: 'prolonger', raison: 'cadre' });
  assert.deepEqual(c({ reste: 1, estime: 76, age: 32 }).conseil, 'garder');
  // Vendre : trentenaire en dessous du niveau et payé plus que la moyenne, ou très loin du niveau.
  assert.deepEqual(c({ age: 31, estime: 60, part: 2 / 36 }), { conseil: 'vendre', raison: 'salaire' });
  assert.deepEqual(c({ age: 31, estime: 60, part: 0.5 / 36 }).conseil, 'garder');
  assert.deepEqual(c({ age: 26, estime: 54 }), { conseil: 'vendre', raison: 'niveau' });
  // Vente en cours : prioritaire.
  assert.deepEqual(c({ vente: true, reste: 0 }), { conseil: 'vente', raison: 'vente' });
  assert.deepEqual(c({}), { conseil: 'garder', raison: 'cadre' });
  assert.deepEqual(c({ estime: 64 }), { conseil: 'garder', raison: 'effectif' });
  for (const id of ['prolonger', 'partir', 'vendre', 'vente', 'garder']) assert.ok(P.CONSEILS.includes(id));
  for (const r of ['vente', 'decide', 'retraite', 'cadre', 'jeune', 'profondeur', 'niveau', 'salaire', 'effectif']) assert.ok(P.RAISONS_CONSEIL[r]);
});

test('Carrière Monde : rôle et conseil envoyés à l’écran, rôles enregistrés, promesse à la prolongation, migration', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    let model = creer(jeu);
    const sous = model.squad.filter(p => Number.isInteger(p.contractEnd) && !p.calledUp);
    assert.ok(sous.length > 20);
    for (const p of sous) {
      assert.ok(['titulaire', 'rotation', 'espoir', 'appoint'].includes(p.roleContrat?.role), p.name + ' : rôle au contrat');
      assert.ok(['prolonger', 'partir', 'vendre', 'vente', 'garder'].includes(p.conseilStaff?.conseil), p.name + ' : conseil du staff');
      assert.ok(P.RAISONS_CONSEIL[p.conseilStaff.raison], p.name + ' : raison du conseil');
    }
    const roles = new Set(sous.map(p => p.roleContrat.role));
    assert.ok(roles.has('titulaire') && roles.has('rotation'), 'hiérarchie variée : ' + [...roles]);
    assert.ok(new Set(sous.map(p => p.conseilStaff.conseil)).size >= 2, 'conseils variés');
    // Rôles enregistrés sur les joueurs du club dès la création.
    assert.equal(lire('S.clubs[S.club].players.filter(p=>Number.isInteger(p.contractEnd)&&!p.espoirLoan&&!p.roleContrat).length'), 0);
    // Migration : une ancienne sauvegarde sans rôle les reçoit à la première commande qui touche aux joueurs.
    jeu.bridge.vm.run('for(const p of S.clubs[S.club].players)delete p.roleContrat;');
    model = jeu.call('set_player_load', { playerId: sous[0].id, mode: 'repos' });
    assert.equal(lire('S.clubs[S.club].players.filter(p=>Number.isInteger(p.contractEnd)&&!p.espoirLoan&&!p.roleContrat?.deduit).length'), 0, 'rôles déduits enregistrés');
    // Prolongation avec rôle promis : enregistré tel quel, sans marque « déduit ».
    const cible = model.squad.find(p => p.renewal?.available);
    assert.ok(cible, 'un joueur à prolonger');
    assert.equal(jeu.brut('extend_contract', { playerId: cible.id, salary: Math.min(100000, Math.ceil(cible.renewal.salary * 1.4 / 100) * 100), years: cible.renewal.minYears, confirmed: true, role: 'capitaine' }).error, 'Offre invalide.');
    // Espoir seulement à 21 ans et moins (temps de jeu promis, idée 16).
    const promis = cible.age <= 21 ? 'espoir' : 'rotation';
    const r = jeu.brut('extend_contract', { playerId: cible.id, salary: Math.min(100000, Math.ceil(cible.renewal.salary * 1.4 / 100) * 100), years: cible.renewal.minYears, confirmed: true, role: promis });
    assert.equal(r.ok, true, r.error);
    const apres = r.model.squad.find(p => p.id === cible.id);
    assert.ok(apres.contractEnd > cible.contractEnd, 'contrat prolongé');
    assert.deepEqual(apres.roleContrat, { role: promis, deduit: false, saison: model.meta.season });
    assert.deepEqual(lire(`S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}).roleContrat`), { role: promis, saison: model.meta.season, fin: apres.contractEnd, club: lire('S.club') });
  } finally { jeu.fermer(); }
});
