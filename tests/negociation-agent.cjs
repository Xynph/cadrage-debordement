'use strict';
// Négociation avec l'agent (revue FM27, idée 18 ; choix A de Léo du 23/11/2026) : l'écran d'offre envoie dans la même
// commande le rôle promis (role-contrat.cjs, idée 16) et les clauses de l'offre guidée (clauses-contrat.cjs, idée 17).
// Contrat de données de l'écran (market[].roles et market[].offre, squad[].renewal.roles) et signature combinée.
const assert = require('node:assert/strict');
const { test } = require('node:test');

test('Carrière Monde : rôle promis + prime + clause dans une seule offre, signature et contrat de l’écran', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    const model = creer(jeu);
    // Club 102 : caisse de départ ramenée à 0,6 M€ (PR économie des ligues) donc enveloppe de transferts de 70 000 € ; ce test paie une prime : budget et caisse relevés (même réglage que clubs-geres-mutations.cjs).
    jeu.bridge.vm.run('S.clubs[S.club].cash=Math.max(S.clubs[S.club].cash,9e6);(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
    // L'écran reçoit, pour chaque piste, la demande de chaque rôle et les crans / clauses de l'offre guidée.
    const pistes = model.market.filter(p => p.available && p.offre && p.roles);
    assert.ok(pistes.length > 3, 'pistes avec rôles et offre guidée');
    for (const p of pistes) {
      assert.deepEqual(p.roles.liste.map(r => r.role), ['titulaire', 'rotation', 'espoir', 'appoint']);
      assert.ok(['titulaire', 'rotation', 'espoir', 'appoint'].includes(p.roles.attendu));
      assert.equal(p.roles.liste.find(r => r.role === p.roles.attendu).salary, p.salary, 'rôle attendu : la demande affichée');
    }
    // Prolongation : rôles envoyés aussi (rôle obligatoire à la prolongation).
    const prolongeables = model.squad.filter(p => p.renewal?.available);
    assert.ok(prolongeables.length > 0 && prolongeables.every(p => p.renewal.roles?.liste?.length === 4), 'prolongation : rôles de l’offre');

    // Une piste qui accepte d'être promise Rotation (refus éventuel : Espoir > 21 ans, Appoint pour un ambitieux).
    const parSalaire = pistes.slice().sort((a, b) => b.salary - a.salary || (a.id < b.id ? -1 : 1));
    const cible = parSalaire.find(p => !p.roles.liste.find(r => r.role === 'rotation').refus);
    assert.ok(cible, 'piste promettable Rotation');
    const id = JSON.stringify(cible.id), annees = Math.min(2, cible.maxYears);
    const prime = cible.fee + cible.offre.crans[annees].at(-1);
    // Seuil réel du moteur avec le rôle, la prime en plus et la clause basse, dans le même ordre que la commande.
    const seuil = lire(`(()=>{const p=S.market.find(x=>x.id===${id});const x=clausesPreparer(p,'recruit',{years:${annees},prime:${prime},clause:'basse'});
      try{return roleContratAvec(p,'rotation',()=>reservationWage(p,'recruit',${annees}));}finally{if(x)clausesFin();}})()`);
    assert.ok(Number.isInteger(seuil) && seuil >= 1000, 'seuil : ' + seuil);
    // Rôle refusé : l'offre est rejetée avant toute négociation.
    const refuse = cible.roles.liste.find(r => r.refus);
    if (refuse) assert.equal(jeu.brut('recruit', { playerId: cible.id, salary: seuil, years: annees, confirmed: true, role: refuse.role }).error, refuse.refus);
    // Rôle inconnu : offre invalide.
    assert.equal(jeu.brut('recruit', { playerId: cible.id, salary: seuil, years: annees, confirmed: true, role: 'capitaine' }).error, 'Offre invalide.');
    const r = jeu.brut('recruit', { playerId: cible.id, salary: seuil, years: annees, confirmed: true, role: 'rotation', prime, clause: 'basse' });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.negotiation.status, 'signed', JSON.stringify(r.model.meta.negotiation));
    assert.equal(r.model.meta.negotiation.fee, prime, 'prime totale payée');
    const signe = lire(`S.clubs[S.club].players.find(p=>p.id===${id})`);
    assert.equal(signe.salary, seuil);
    assert.equal(signe.roleContrat.role, 'rotation');
    assert.equal(signe.roleContrat.deduit, undefined, 'rôle promis explicitement');
    assert.equal(signe.clauseLiberatoire.niveau, 'basse');
    // L'écran de l'effectif le lit : rôle promis (non déduit).
    const vu = r.model.squad.find(p => p.id === cible.id);
    assert.deepEqual([vu.roleContrat.role, vu.roleContrat.deduit], ['rotation', false]);
    assert.equal(lire('(validateCareer(S),true)'), true);
    // Déterminisme : même carrière, même seuil.
    const jeu2 = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
    try {
      creer(jeu2);
      const seuil2 = JSON.parse(jeu2.bridge.vm.run(`JSON.stringify((()=>{const p=S.market.find(x=>x.id===${id});const x=clausesPreparer(p,'recruit',{years:${annees},prime:${prime},clause:'basse'});
        try{return roleContratAvec(p,'rotation',()=>reservationWage(p,'recruit',${annees}));}finally{if(x)clausesFin();}})())`));
      assert.equal(seuil2, seuil, 'même seuil sur une carrière identique');
    } finally { jeu2.fermer(); }
  } finally { jeu.fermer(); }
});
