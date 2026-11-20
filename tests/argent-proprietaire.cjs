'use strict';
// L'argent du propriétaire (club-owner.cjs) : actionnaire qui prête au lieu de donner, mécènes qui arrivent et qui
// partent. Mode Monde uniquement.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const O = require('../native/engine/club-owner.cjs');
const B = require('../native/engine/club-budget.cjs');
const H = require('../native/engine/club-finance-health.cjs');
const M = require('./helpers/carriere-monde.cjs');

test('Prêteurs : un groupe actionnaire sur deux, rarement un mécène, jamais une association ; trait stable', () => {
  const part = type => Array.from({ length: 3000 }, (_, i) => O.preteur(i, type)).filter(Boolean).length / 3000;
  assert.ok(Math.abs(part('entreprise') - 0.5) < 0.04, 'entreprise ' + part('entreprise'));
  assert.ok(Math.abs(part('mecene') - 0.15) < 0.03, 'mécène ' + part('mecene'));
  assert.equal(part('association'), 0);
  for (let i = 0; i < 50; i++) assert.equal(O.preteur(i, 'entreprise'), O.preteur(i, 'entreprise'));
});

test('Prêt : plafonné à l’enveloppe du propriétaire, remboursé en trois saisons à partir de la suivante', () => {
  const a = O.accorder(null, 900000, 4, 1.2e6);
  assert.deepEqual(a, { pret: { restant: 900000, annuite: 300000, saison: 4, dernier: 900000 }, prete: 900000 });
  assert.equal(O.remboursementSaison(a.pret, 4), 0, 'pas de remboursement la saison même');
  assert.equal(O.remboursementSaison(a.pret, 5), 300000);
  // Encours au plafond : le propriétaire ne prête plus que ce qui reste sous son enveloppe, au-delà il comble.
  const b = O.accorder(a.pret, 600000, 5, 1.2e6);
  assert.equal(b.prete, 300000);
  assert.equal(b.pret.restant, 1.2e6);
  assert.equal(b.pret.annuite, 400000);
  assert.equal(O.accorder(b.pret, 500000, 6, 1.2e6).prete, 0);
  assert.equal(O.accorder(null, 2e6, 6, 3e6).prete, 1.5e6, 'jamais plus de 1,5 M€ d’encours');
  assert.equal(O.accorder(null, 20000, 6, 1e6).prete, 0, 'pas de prêt pour une broutille');
});

test('Limites salariales : le remboursement de la saison réduit la marge des salaires, rien d’autre ne bouge', () => {
  const forces = Array.from({ length: 16 }, (_, i) => ({ id: i, division: 'accession', base: 62 + i }));
  const sans = B.limites(forces, 3), avec = B.limites(forces, 3, { remboursements: { 5: 280000 } });
  for (const [id, l] of sans) {
    if (id === 5) { if (l.regle === 'budget') assert.ok(Math.abs(l.limite - avec.get(5).limite - 280000 / 1.4 * l.tolerance) < 200, 'borne budget réduite de 280 000 / 1,4'); }
    else assert.equal(avec.get(id).limite, l.limite);
  }
});

test('Étiquette : le prêt de l’actionnaire pèse sur la caisse nette sans rendre fragile à lui seul', () => {
  assert.equal(H.etiquette({ tresorerie: 3e6, reserve: 2e6, dette: 0.6e6, pret: 0.6e6 }), 'saine');
  assert.equal(H.etiquette({ tresorerie: 3e6, reserve: 2e6, dette: 0.6e6 }), 'fragile');
});

test('Changements de propriétaire : rares, deux au plus par saison, motifs lisibles', () => {
  const rep = { elite: 100, accession: 70, nationale: 50 };
  const clubs = Array.from({ length: 116 }, (_, i) => ({ id: i, type: ['mecene', 'entreprise', 'association'][i % 3], avant: i < 14 ? 'elite' : i < 30 ? 'accession' : 'nationale',
    apres: i < 14 ? 'elite' : i < 30 ? 'accession' : 'nationale', rang: (i % 16) + 1, taille: 16, base: 60 + (i % 25), pertes: i % 5 === 0 ? 3 : 0 }));
  clubs[13].apres = 'accession'; clubs[12].apres = 'accession'; // deux descentes (mécène 12 seulement)
  let total = 0;
  for (let saison = 2; saison < 52; saison++) {
    const l = O.changements(clubs, saison, rep);
    assert.ok(l.length <= 2);
    for (const x of l) {
      assert.ok(x.vers === 'mecene' ? clubs[x.id].apres === 'accession' && clubs[x.id].rang <= 6 && x.de !== 'mecene' : x.de === 'mecene');
      assert.ok(['ambition', 'descente', 'resultats', 'pertes'].includes(x.raison));
      assert.ok(O.annonce('Club', x).length > 40);
    }
    total += l.length;
  }
  assert.ok(total / 50 >= 0.5 && total / 50 <= 2, 'changements par saison : ' + total / 50);
});

test('Moteur Monde : prêt du club joué, remboursement hebdomadaire, courrier du président et vente proposée', { timeout: 600000 }, () => {
  const jeu = M.ouvrir({ testVm: true, mandatoryPress: false });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 19, start: 'veille' }));
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    // Le propriétaire de Nice (club 19) devient un groupe actionnaire prêteur ; la saison passée s'est close sur une perte comblée.
    const pret = lire(`(()=>{const k=S.clubBudget.clubs[S.club];k.type='entreprise';k.enveloppe=900000;const avant=worldClub(S.club).debt;
      const prete=pretAccorder(S.club,k,700000,S.season-1);return {prete,dette:worldClub(S.club).debt-avant,crise:detteDeCrise(S.club),p:S.pretsActionnaires[S.club],
       sante:santeFiche(S.club).etiquette};})()`);
    assert.equal(pret.prete, 700000);
    assert.equal(pret.dette, 700000, 'prêt inscrit dans la dette du club');
    assert.equal(pret.crise, 0, 'pas une dette de crise');
    assert.ok(pret.p.vente && pret.p.vente.prix > 0, 'joueur proposé : ' + JSON.stringify(pret.p));
    // Comptes rouverts : remboursement de la saison, écriture hebdomadaire, dette qui baisse, résultat non pénalisé.
    const semaine = lire(`(()=>{budgetOuvrir(false);const k=S.clubBudget.clubs[S.club];const avant=worldClub(S.club).debt;
      const e=budgetSemaine(budgetForces(),budgetRepere(),club(),null,'Test');const l=e.find(x=>x.title.endsWith(nativeClubBudget.LIBELLE_REMBOURSEMENT));
      return {remboursement:k.remboursement,ligne:l?.amount??null,baisse:avant-worldClub(S.club).debt,rembourse:k.rembourse,charges:k.charges};})()`);
    assert.ok(Math.abs(semaine.remboursement - 234000) <= 1000, 'annuité : ' + semaine.remboursement);
    assert.ok(semaine.ligne < 0 && semaine.baisse === -semaine.ligne && semaine.rembourse === -semaine.ligne, JSON.stringify(semaine));
    // Courrier du président au jour suivant, puis vente du joueur proposé.
    for (let j = 0; j < 12 && !model.clubLife?.clubMail?.mails?.some(m => m.type === 'pret_actionnaire'); j++) model = jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));
    const mail = model.clubLife.clubMail.mails.find(m => m.type === 'pret_actionnaire');
    assert.ok(mail, 'courrier du prêt : ' + JSON.stringify(model.clubLife.clubMail.mails.map(m => m.type)));
    assert.match(mail.corps, /prêt/);
    assert.equal(mail.reponses.length, 2);
    assert.ok(mail.reponses.every(r => r.disponible), JSON.stringify(mail.reponses));
    const joueur = lire('S.pretsActionnaires[S.club].vente.joueur'), avant = lire('({dette:worldClub(S.club).debt,cash:club().cash,n:club().players.length})');
    // La vente est conclue tout de suite et exécutée au changement de saison (calendrier-mutations v2, décision de Léo du
    // 19/11/2026) ; l'argent est encaissé et le prêt remboursé dès l'accord (décision de Léo du 20/11/2026).
    assert.match(mail.corps, /prennent effet au changement de saison/);
    const r = jeu.brut('club_mail_reply', { id: mail.id, choice: 'vendre' });
    assert.equal(r.ok, true, r.error);
    const conclu = lire(`({dette:worldClub(S.club).debt,n:club().players.length,ici:club().players.some(p=>p.id===${JSON.stringify(joueur)}),
      accord:S.venteJoueurs.accords.find(a=>a.playerId===${JSON.stringify(joueur)})||null})`);
    assert.equal(conclu.ici, true, 'il reste jusqu’à l’ouverture'); assert.equal(conclu.n, avant.n); assert.ok(conclu.dette < avant.dette, 'prêt remboursé à l’accord');
    assert.ok(conclu.accord && conclu.accord.imposee && conclu.accord.pret, JSON.stringify(conclu.accord));
    assert.match(conclu.accord.date, /-07-01$/); assert.equal(conclu.accord.bascule, true);
    // Changement de saison (ventes de settleContracts) : le joueur part, sans nouveau mouvement d'argent.
    const apres = lire(`(()=>{venteExecuterAccords('ventes');
        return {dette:worldClub(S.club).debt,cash:club().cash,n:club().players.length,ici:club().players.some(p=>p.id===${JSON.stringify(joueur)}),pret:S.pretsActionnaires[S.club]??null,
        lignes:S.ledger.slice(0,4).map(e=>e.title)};})()`);
    jeu.call('save');
    assert.equal(apres.ici, false, 'joueur vendu');
    assert.equal(apres.n, avant.n - 1);
    assert.equal(apres.dette, conclu.dette, 'rien de plus au départ : ' + JSON.stringify([avant, conclu, apres]));
    assert.ok(apres.lignes.some(t => /Remboursement anticipé/.test(t)) && apres.lignes.some(t => /^Vente/.test(t)), JSON.stringify(apres.lignes));
  } finally { jeu.fermer(); }
});

test('Moteur Monde : changement de propriétaire du club joué, courrier et confiance', { timeout: 600000 }, () => {
  const jeu = M.ouvrir({ testVm: true, mandatoryPress: false });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 19, start: 'veille' }));
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    // Arrivée d'un investisseur au club joué (forcée par le test : le tirage réel est rare).
    const r = lire(`(()=>{const t=S.trust,k=S.clubBudget.clubs[S.club];k.type='association';const de=k.type;
      proprietairesChanger([{id:S.club,de,vers:'mecene',raison:'ambition'}]);
      budgetOuvrir(true,false);return {avant:t,apres:S.trust,type:S.clubBudget.clubs[S.club].type,historique:S.proprietaires.historique.length};})()`);
    assert.equal(r.type, 'mecene');
    assert.equal(r.apres - r.avant, 5);
    assert.equal(r.historique, 1);
    for (let j = 0; j < 12 && !model.clubLife?.clubMail?.mails?.some(m => m.type === 'proprietaire_arrivee'); j++) model = jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));
    const mail = model.clubLife.clubMail.mails.find(m => m.type === 'proprietaire_arrivee');
    assert.ok(mail && mail.reponses.length === 2, 'courrier du nouvel actionnaire');
    assert.equal(jeu.brut('club_mail_reply', { id: mail.id, choice: 'ambition' }).ok, true);
  } finally { jeu.fermer(); }
});
