'use strict';
// Offre guidée (revue FM27, idée 17 ; décision de Léo du 23/11/2026) : prime à la signature négociable, clause libératoire
// (négociée à la signature, payée par un club géré = départ), prix d'ouverture sous la demande du vendeur, clause des joueurs
// des clubs gérés (native/engine/clauses-contrat.cjs, gestion.cjs, interclub-market.cjs).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/clauses-contrat.cjs');

test('Clauses : trois niveaux multiples de la valeur, effet sur le salaire 2 / 4 / 7 %', () => {
  assert.deepEqual(K.niveaux(300000), [
    { niveau: 'sans', montant: 0, remise: 0 },
    { niveau: 'haute', montant: 750000, remise: 0.02 },
    { niveau: 'moyenne', montant: 480000, remise: 0.04 },
    { niveau: 'basse', montant: 300000, remise: 0.07 },
  ]);
  // Plancher de 20 000 € et arrondi à 10 000 € supérieurs.
  assert.deepEqual(K.niveaux(1234).map(x => x.montant), [0, 20000, 20000, 20000]);
  assert.equal(K.niveaux(123456)[1].montant, 310000);
  assert.equal(K.remise('sans'), 0);
  assert.equal(K.remise('inconnue'), 0);
});

test('Prime en plus : crans de 5, 10 et 15 % des salaires demandés, salaire minimum abaissé euro pour euro', () => {
  assert.deepEqual(K.crans(1000, 46, 2), [0, 5000, 10000, 14000]);
  assert.deepEqual(K.crans(5000, 46, 3), [0, 35000, 69000, 104000]);
  assert.deepEqual(K.crans(100, 46, 1), [0, 1000], 'petits salaires : crans de 1 000 € fusionnés');
  // Minimum sans rien : arrondi à la centaine supérieure.
  assert.equal(K.minimum(4321), 4400);
  // Clause basse : −7 %.
  assert.equal(K.minimum(5000, { niveau: 'basse' }), 4700);
  // Prime en plus de 46 000 € sur 2 saisons de 46 semaines : −500 €/semaine.
  assert.equal(K.minimum(5000, { extra: 46000, semaines: 46, annees: 2 }), 4500);
  // Baisse plafonnée à 15 % du salaire.
  assert.equal(K.minimum(5000, { extra: 1e9, semaines: 46, annees: 1 }), 4300);
  assert.equal(K.minimum(5000, { niveau: 'basse', extra: 1e9, semaines: 46, annees: 1 }), 3900);
});

test('Clauses des clubs gérés et prix d’ouverture : déterministes, un joueur sur trois environ', () => {
  const ids = Array.from({ length: 3000 }, (_, i) => 'j' + i);
  const avec = ids.map(id => K.clauseIA(id, 1000, 3)).filter(Boolean);
  assert.ok(avec.length > 900 && avec.length < 1200, 'part des joueurs avec clause : ' + avec.length);
  for (const m of avec) assert.ok(m >= 130000 && m <= 240000 && m % 10000 === 0, 'clause de 2,5 à 4,5 saisons : ' + m);
  assert.equal(K.clauseIA('j1', 1000, 3), K.clauseIA('j1', 1000, 3));
  assert.equal(K.clauseIA('j1', 0, 3), null);
  for (const id of ids.slice(0, 300)) {
    const m = K.vendeurMinimum(id, 2, 200000);
    assert.ok(m >= 180000 && m <= 190000 && m % 1000 === 0, 'vendeur : 90 à 95 % de sa demande : ' + m);
    assert.equal(m, K.vendeurMinimum(id, 2, 200000));
  }
  assert.equal(K.vendeurMinimum('x', 1, 20000) <= 20000, true);
  const tirees = Array.from({ length: 2000 }, (_, w) => K.semaineTiree(4242, 1, w)).filter(Boolean).length;
  assert.ok(tirees > 30 && tirees < 95, 'semaines tirées pour une clause payée (3 %) : ' + tirees);
});

test('Carrière Monde : offre avec prime et clause, contre-offre, signature, clause payée par un club géré, sauvegarde', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    let model = creer(jeu);
    // Club 102 : caisse de départ ramenée à 0,6 M€ (PR économie des ligues) donc enveloppe de transferts de 70 000 € ; ce test paie une prime : budget et caisse relevés (même réglage que clubs-geres-mutations.cjs).
    jeu.bridge.vm.run('S.clubs[S.club].cash=Math.max(S.clubs[S.club].cash,9e6);(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
    // Offre au joueur : crans de prime et clauses envoyés à l'écran.
    const libres = model.market.filter(p => p.available && p.offre);
    assert.ok(libres.length > 3, 'joueurs libres avec offre');
    for (const p of libres) {
      assert.deepEqual(p.offre.clauses.map(c => c.niveau), ['sans', 'haute', 'moyenne', 'basse']);
      assert.equal(p.offre.primeBase, p.fee);
      assert.ok(p.offre.crans[3].length >= 2 && p.offre.crans[3][0] === 0);
    }
    const cible = libres.slice().sort((a, b) => b.salary - a.salary)[0];
    const id = JSON.stringify(cible.id), annees = Math.min(2, cible.maxYears);
    const max = cible.offre.crans[3].at(-1), prime = cible.fee + cible.offre.crans[annees].at(-1);
    // Salaire minimum accepté : plus bas avec la prime en plus et la clause basse.
    const seuil = (niveau, primeTotale) => lire(`(()=>{const p=S.market.find(x=>x.id===${id});clausesPreparer(p,'recruit',{years:${annees},prime:${primeTotale},clause:'${niveau}'});try{return reservationWage(p,'recruit',${annees});}finally{clausesFin();}})()`);
    const avant = lire(`reservationWage(S.market.find(x=>x.id===${id}),'recruit',${annees})`);
    assert.equal(seuil('sans', cible.fee), avant, 'sans prime ni clause : seuil inchangé');
    const apres = seuil('basse', prime);
    assert.ok(apres < avant, `seuil abaissé : ${avant} → ${apres}`);
    assert.equal(lire(`reservationWage(S.market.find(x=>x.id===${id}),'recruit',${annees})`), avant, 'effet limité à la commande');
    // Offres invalides.
    assert.match(jeu.brut('recruit', { playerId: cible.id, salary: apres, years: annees, confirmed: true, prime: cible.fee - 1000 }).error, /Prime invalide/);
    assert.match(jeu.brut('recruit', { playerId: cible.id, salary: apres, years: annees, confirmed: true, prime: cible.fee + max + 1000 }).error, /Prime invalide/);
    assert.equal(jeu.brut('recruit', { playerId: cible.id, salary: apres, years: annees, confirmed: true, clause: 'nulle' }).error, 'Offre invalide.');
    // Sous le seuil : contre-offre au seuil.
    assert.ok(apres - 100 >= 1000, 'seuil assez haut pour tester la contre-offre : ' + apres);
    {
      const r = jeu.brut('recruit', { playerId: cible.id, salary: apres - 100, years: annees, confirmed: true, prime, clause: 'basse' });
      assert.equal(r.ok, true, r.error);
      assert.equal(r.model.meta.negotiation.status, 'counter');
      assert.equal(r.model.meta.negotiation.salary, apres, 'contre-offre au salaire minimum avec prime et clause');
    }
    // Signature : prime payée, clause posée sur le joueur.
    const caisse = lire('S.clubs[S.club].cash');
    const r = jeu.brut('recruit', { playerId: cible.id, salary: apres, years: annees, confirmed: true, prime, clause: 'basse' });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.negotiation.status, 'signed');
    const basse = cible.offre.clauses.find(c => c.niveau === 'basse').montant;
    assert.equal(r.model.meta.negotiation.fee, prime);
    assert.equal(r.model.meta.negotiation.clauseMontant, basse);
    assert.ok(caisse - lire('S.clubs[S.club].cash') >= prime, 'prime payée');
    const signe = lire(`S.clubs[S.club].players.find(p=>p.id===${id})`);
    assert.equal(signe.salary, apres);
    assert.deepEqual(signe.clauseLiberatoire, { niveau: 'basse', montant: basse, saison: lire('S.season'), fin: signe.contractEnd, club: lire('S.club') });
    assert.deepEqual(lire(`clauseJoueur(S.clubs[S.club].players.find(p=>p.id===${id}),S.club)`), { niveau: 'basse', montant: basse, saison: lire('S.season') });
    model = r.model;

    // Marché entre clubs : prix d'ouverture sous la demande, contre-offre du vendeur.
    const ic = model.clubLife.interclubMarket;
    const avecClause = ic.candidates.filter(c => Number.isInteger(c.clause));
    assert.ok(avecClause.length > ic.candidates.length * 0.25 && avecClause.length < ic.candidates.length * 0.45, 'clauses des clubs gérés : ' + avecClause.length + '/' + ic.candidates.length);
    // Indemnité d'au moins 20 000 € : le budget de transferts restant (environ 27 000 € après la signature plus haut) dépend du salaire signé et de la billetterie réelle.
    const achat = ic.candidates.find(c => c.available && c.fee >= 20000 && !c.clauseRequise);
    assert.ok(achat, 'un joueur achetable');
    {
      const offre = fee => jeu.brut('interclub_negotiate', { playerId: achat.id, sellerId: achat.clubId, fee, salary: achat.salary, sourceSalary: achat.sourceSalary, contractEnd: achat.contractEnd, context: ic.context });
      const bas = offre(Math.floor(achat.fee * 0.8 / 1000) * 1000);
      assert.equal(bas.ok, true, bas.error);
      const v = bas.model.meta.interclubNegotiation.seller;
      assert.equal(v.accepted, false);
      assert.ok(v.counter >= achat.fee * 0.9 && v.counter <= achat.fee, 'contre-offre du vendeur entre 90 et 100 % : ' + v.counter + ' / ' + achat.fee);
      assert.equal(offre(v.counter).model.meta.interclubNegotiation.seller.accepted, true, 'le vendeur accepte son minimum');
    }
    // Vendeur qui ne veut pas vendre (garde d'effectif) : seule la clause le fait céder.
    const forcee = lire(`(()=>{const pol=nativeSystems.domain('interclubMarket').releasePolicy(S).minimum;
      for(const c of S.clubs){if(c.id===S.club)continue;const p=c.players.find(q=>clauseIA(q)&&q.contractEnd>S.season&&q.age<32);if(!p)continue;
        c.players=[p,...c.players.filter(q=>q.id!==p.id)].slice(0,pol);nativeSystems.clearMemo();return {id:p.id,club:c.id};}return null;})()`);
    assert.ok(forcee, 'un joueur de club géré avec clause');
    // Sans commande (le cycle des effectifs gérés recompléterait le club) : projection et négociation lues directement.
    const ic2 = lire(`nativeSystems.domain('interclubMarket').project()`);
    const bloque = ic2.candidates.find(c => c.id === forcee.id);
    assert.equal(bloque.clauseRequise, true);
    assert.match(bloque.garde, /Le vendeur conserve au moins/);
    const negocier = fee => lire(`nativeSystems.execute('interclub_negotiate',${JSON.stringify({ playerId: bloque.id, sellerId: bloque.clubId, fee, salary: bloque.salary, sourceSalary: bloque.sourceSalary, contractEnd: bloque.contractEnd, context: ic2.context })}).interclubNegotiation`);
    const refus = negocier(bloque.fee);
    assert.equal(refus.seller.accepted, false);
    assert.equal(refus.seller.counter, bloque.clause);
    assert.match(refus.seller.reason, /clause libératoire/);
    const payee = negocier(bloque.clause);
    assert.equal(payee.seller.accepted, true);
    assert.equal(payee.seller.clause, true);
    assert.ok(payee.offers.every(o => o.human), 'aucun club géré n’enchérit sur un joueur que son club garde');

    // Clause payée par un club géré : jamais la saison de la signature, puis départ au changement de saison, argent encaissé.
    const dom = 'nativeSystems.domain("clausesContrat")';
    assert.equal(lire(`${dom}.activer({force:true})`), null, 'clause signée cette saison : protégée');
    jeu.bridge.vm.run(`for(const p of S.clubs[S.club].players)if(p.contractEnd>S.season)p.clauseLiberatoire={niveau:'basse',montant:20000,saison:S.season-1,fin:p.contractEnd,club:S.club};`);
    const caisse2 = lire('S.clubs[S.club].cash');
    const act = lire(`${dom}.activer({force:true})`);
    assert.ok(act && act.montant === 20000 && act.saison === lire('S.season'), 'un club géré paie une clause basse : ' + JSON.stringify(act));
    assert.equal(lire('S.clubs[S.club].cash') - caisse2, 20000, 'argent encaissé à l’accord');
    assert.ok(lire(`S.venteJoueurs.accords.some(a=>a.playerId===${JSON.stringify(act.playerId)}&&a.clause===true&&a.paye===true)`), 'départ au changement de saison');
    assert.equal(lire(`${dom}.activer({force:true})`), null, 'une seule clause payée par saison');
    // Sauvegarde : état valide, clause invalide refusée.
    assert.equal(lire('(validateCareer(S),true)'), true);
    jeu.bridge.vm.run(`S.clubs[S.club].players[0].clauseLiberatoire={niveau:'gratuite',montant:1,saison:1,fin:1,club:S.club};`);
    assert.throws(() => jeu.bridge.vm.run('validateCareer(S)'), /Clause libératoire invalide/);
  } finally { jeu.fermer(); }
});
