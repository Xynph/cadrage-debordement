'use strict';
// Calendrier du recrutement (native/engine/calendrier-mutations.cjs, docs/gdd/calendrier-mutations.md) : dates limites
// (joueurs sans club jusqu'au 31 décembre, deux joueurs supplémentaires en janvier, jokers jusqu'au 31 mars, période des
// mutations du 1er mai au 30 juin), accord d'achat différé exécuté au changement de saison (v2), pré-contrats dans les deux sens
// (arrivée au 1er juillet sans indemnité), approche d'un autre club (courrier, délai, prolongation qui l'annule), vente du
// président différée, part des ventes rendue au budget sans plafond, temps de clôture de semaine.
// Mode Monde uniquement (`world-champ`, club 102).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/calendrier-mutations.cjs');
const R = require('../native/engine/calendrier-mutations.json');
const RV = require('../native/engine/vente-joueurs.json');
const T = require('../native/engine/budget-transferts.cjs');
const { ouvrir, creer, jouerLeMatch } = require('./helpers/carriere-monde.cjs');

const CLUB = 102;
const copie = x => JSON.parse(JSON.stringify(x));
const ORIGINE = { cal: copie(R), vente: copie(RV) };
// Réglages modifiés le temps d'un test (le moteur lit les mêmes objets JSON, dans le même processus).
const restaurer = () => {
  for (const k of Object.keys(ORIGINE.cal)) R[k] = copie(ORIGINE.cal[k]);
  for (const k of Object.keys(ORIGINE.vente)) RV[k] = copie(ORIGINE.vente[k]);
};
const decaler = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10);
const md = iso => iso.slice(5, 10);
const outils = jeu => {
  const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
  const run = s => { const r = jeu.bridge.vm.run(s); jeu.call('save'); return r; };
  const jour = () => lire('CDWorldCareer.calendarToday(S)');
  // Clôt la semaine (match du club joué délégué s'il y en a un).
  const semaine = () => { const m = jeu.regler(jeu.call('snapshot')); return m.next ? jouerLeMatch(jeu, m) : jeu.regler(jeu.call('finish_round')); };
  // Période des mutations ouverte d'aujourd'hui à dans `duree` jours.
  const mutationsOuvertes = (duree = 40) => { const j = jour(); RV.fenetres.periodes = [{ debut: md(j), fin: md(decaler(j, duree)) }]; };
  return { lire, run, jour, semaine, mutationsOuvertes };
};

test('Dates limites : joueurs sans club, joueurs supplémentaires, mutations, jokers, pré-contrats, tirage', () => {
  try {
    // Joueurs sans club : ouverts jusqu'au 31 décembre.
    let l = K.libres('2026-08-17');
    assert.equal(l.ouverte, true); assert.equal(l.fin, '2026-12-31'); assert.equal(l.supplementaire, false);
    assert.equal(l.note, 'Joueurs sans club : recrutement ouvert jusqu’au 31 décembre 2026.');
    assert.equal(K.libres('2026-12-31').ouverte, true);
    // Janvier : deux joueurs supplémentaires par saison.
    l = K.libres('2027-01-01', 0);
    assert.deepEqual([l.ouverte, l.supplementaire, l.restants], [true, true, 2]);
    assert.equal(l.note, 'Joueurs supplémentaires jusqu’au 31 janvier 2027 : encore 2 sur 2 cette saison.');
    assert.equal(K.libres('2027-01-31', 1).restants, 1);
    l = K.libres('2027-01-15', 2);
    assert.equal(l.ouverte, false);
    assert.equal(l.raison, 'Les 2 joueurs supplémentaires de la saison sont déjà recrutés : recrutement des joueurs sans club rouvert le 1er mai 2027.');
    // Février à avril : fermé, raison écrite avec la date de réouverture.
    l = K.libres('2027-02-01');
    assert.equal(l.ouverte, false); assert.equal(l.reouverture, '2027-05-01');
    assert.equal(l.raison, 'Recrutement des joueurs sans club fermé depuis le 31 janvier : réouverture le 1er mai 2027.');
    assert.equal(K.libres('2027-04-30').ouverte, false);
    assert.equal(K.libres('2027-05-01').ouverte, true);
    // Joueurs sous contrat entre clubs : période des mutations du 1er mai au 30 juin.
    assert.deepEqual(K.interclub('2026-08-17'), { ouverte: false, reouverture: '2027-05-01', raison: 'Hors période des mutations : un accord conclu maintenant sera effectif le 1er mai 2027.', note: 'Hors période des mutations : un accord conclu maintenant sera effectif le 1er mai 2027.' });
    assert.equal(K.interclub('2027-05-01').ouverte, true);
    assert.equal(K.interclub('2027-06-30').note, 'Période des mutations ouverte jusqu’au 30 juin 2027 : les accords entre clubs sont immédiats.');
    assert.equal(K.interclub('2027-07-01').reouverture, '2028-05-01');
    // Jokers : jusqu'au 31 mars (période à cheval sur le 1er janvier).
    assert.equal(K.jokers('2026-08-17').ouverte, true);
    assert.equal(K.jokers('2027-03-31').ouverte, true);
    assert.deepEqual(K.jokers('2027-04-01'), { ouverte: false, reouverture: '2027-07-01', fin: null });
    // Pré-contrats : contrat qui s'achève en juin 2027 → possible dès le 1er janvier, arrivée le 1er juillet.
    assert.deepEqual(K.preContratDates(2027), { debut: '2027-01-01', fin: '2027-06-30', arrivee: '2027-07-01' });
    assert.equal(K.prime(12345), 25000, 'deux semaines de salaire, au millier supérieur');
    // Tirage des approches : déterministe.
    const tirees = g => Array.from({ length: 46 }, (_, w) => K.approcheTiree(g, 1, w)).map((x, w) => x ? w : -1).filter(w => w >= 0);
    assert.deepEqual(tirees(4242), tirees(4242));
    assert.ok(tirees(4242).length > 0);
    // Réglage « saison » : tout ouvert (ancien comportement) ; changer le JSON change le jeu.
    R.mode = 'saison';
    assert.equal(K.libres('2027-03-01').ouverte, true); assert.equal(K.jokers('2027-04-10').ouverte, true);
    restaurer();
    R.supplementaires.maxParSaison = 3;
    assert.equal(K.libres('2027-01-10', 2).restants, 1);
  } finally { restaurer(); }
});

test('Budget de transferts (R4) : la part d’une vente choisie n’est plus plafonnée par les recettes', () => {
  const P = T.REGLAGES, plein = { enveloppe: 1e6, depense: 0, reconstitue: 1e7 };
  assert.equal(T.rendu(plein, 600000, 1e6), Math.round(P.partVentes * 600000));
  assert.equal(T.disponible({ ...plein, reconstitue: plein.reconstitue + 300000 }, 2.5e6, 2e6), 500000, 'la caisse reste la seule limite');
});

test('Moteur Monde : recrutement libre, joueurs supplémentaires, achat différé, pré-contrats, approche, président, budget', { timeout: 900000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let m = creer(jeu, CLUB);
    const { lire, run, jour, semaine, mutationsOuvertes } = outils(jeu);
    const aujourdhui = jour();
    assert.ok(aujourdhui >= '2026-07-01' && aujourdhui <= '2026-12-31', aujourdhui);
    assert.equal(m.mutations.available, true);
    assert.equal(m.mutations.freeAgents.open, true);
    assert.equal(m.mutations.interclub.open, false);
    assert.equal(m.mutations.interclub.reopensLabel, '1er mai 2027');
    assert.equal(m.mutations.summary, 'Joueurs libres : ouvert jusqu’au 31 décembre');
    run('club().cash=Math.max(club().cash,9e6)');
    run('(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');

    // 1. Joueurs sans club hors période (février simulé) : raison écrite, commande refusée.
    const ferme = (periodeLibre, periodeSupp) => { R.libres.periodes = [periodeLibre]; R.supplementaires.periodes = [periodeSupp]; };
    const loin = { debut: md(decaler(aujourdhui, 60)), fin: md(decaler(aujourdhui, 90)) };
    ferme(loin, { debut: md(decaler(aujourdhui, 100)), fin: md(decaler(aujourdhui, 110)) });
    m = jeu.call('snapshot');
    const raison = m.mutations.freeAgents.reason;
    assert.match(raison, /^Recrutement des joueurs sans club fermé depuis le .+ : réouverture le .+\.$/);
    const libre = m.market.slice().sort((a, b) => a.fee - b.fee)[0];
    assert.equal(libre.available, false); assert.equal(libre.reason, raison);
    let r = jeu.brut('recruit', { playerId: libre.id, salary: Math.min(100000, Math.ceil(libre.salary * 1.4 / 100) * 100), years: 1, confirmed: true });
    assert.equal(r.ok, false); assert.equal(r.error, raison);

    // 2. Joueurs supplémentaires (janvier simulé) : deux recrues, puis refus.
    ferme(loin, { debut: md(aujourdhui), fin: md(decaler(aujourdhui, 20)) });
    m = jeu.call('snapshot');
    assert.equal(m.mutations.freeAgents.supplementary, true); assert.equal(m.mutations.freeAgents.remaining, 2);
    const signer = () => {
      const p = jeu.call('snapshot').market.filter(x => x.available).sort((a, b) => a.fee - b.fee)[0];
      assert.ok(p, 'joueur libre disponible');
      return jeu.brut('recruit', { playerId: p.id, salary: Math.min(100000, Math.ceil(p.salary * 1.4 / 100) * 100), years: 1, confirmed: true });
    };
    for (const reste of [1, 0]) {
      r = signer(); assert.equal(r.ok, true, r.error);
      assert.equal(r.model.mutations.freeAgents.remaining ?? 0, reste);
    }
    assert.equal(lire('S.calendrierMutations.supplementaires.ids.length'), 2);
    m = jeu.call('snapshot');
    assert.equal(m.mutations.freeAgents.open, false);
    assert.match(m.mutations.freeAgents.reason, /^Les 2 joueurs supplémentaires de la saison sont déjà recrutés/);
    assert.ok(m.market.every(p => !p.available));
    // Les deux recrues repartent (places libres pour la suite du test).
    run(`(()=>{const ids=new Set(S.calendrierMutations.supplementaires.ids);club().players=club().players.filter(p=>!ids.has(p.id));S.lineup=S.lineup.map(x=>ids.has(x)?null:x);S.reserves=S.reserves.map(x=>ids.has(x)?null:x);})()`);
    restaurer();

    // 3. Jokers : renforts parmi les joueurs sans club jusqu'au 31 mars.
    assert.equal(lire('calendrierJokersOuverts()'), true);
    R.jokers.periodes = [loin];
    assert.equal(lire('calendrierJokersOuverts()'), false);
    restaurer();

    // 4. Achat entre clubs hors période : accord conclu, indemnité engagée sur le budget, exécuté à l'ouverture.
    const marche = () => lire(`nativeSystems.domain('interclubMarket').project()`);
    let liste = marche();
    assert.equal(liste.window.open, false); assert.equal(liste.window.reopensLabel, '1er mai 2027');
    const cible = liste.candidates.filter(c => c.available && c.fee <= 400000).sort((a, b) => a.fee - b.fee || (a.id < b.id ? -1 : 1))[0];
    assert.ok(cible, 'joueur sous contrat abordable');
    const offre = { playerId: cible.id, sellerId: cible.clubId, fee: cible.fee, salary: cible.salary, sourceSalary: cible.sourceSalary, contractEnd: cible.contractEnd, context: liste.context };
    const neg = jeu.call('interclub_negotiate', offre).meta.interclubNegotiation;
    assert.equal(neg.humanReady, true, neg.humanReason);
    assert.deepEqual(neg.offers.map(o => o.human), [true], 'hors période, les autres clubs n’enchérissent pas');
    assert.equal(neg.deferred.dateLabel, '1er juillet 2027', 'v2 : arrivée au changement de saison');
    const avantAchat = lire(`({cash:club().cash,n:club().players.length,dep:S.budgetTransferts.depense,vendeur:S.clubs[${cible.clubId}].cash})`);
    r = jeu.brut('interclub_auction', { ...offre, expectedWinner: neg.winner.clubId, expectedFee: neg.winner.fee, expectedSalary: neg.winner.salary, confirmed: true });
    assert.equal(r.ok, true, r.error);
    const recu = r.model.meta.interclubTransfer;
    assert.equal(recu.deferred, true); assert.equal(recu.date, '2027-07-01'); assert.equal(recu.humanWon, true);
    // Décision de Léo du 20/11/2026 : l'indemnité passe d'une caisse à l'autre dès l'accord ; le joueur arrive au 1er juillet.
    assert.deepEqual(lire(`({cash:club().cash,n:club().players.length,dep:S.budgetTransferts.depense,vendeur:S.clubs[${cible.clubId}].cash})`),
      { cash: avantAchat.cash - cible.fee, n: avantAchat.n, dep: avantAchat.dep + cible.fee, vendeur: avantAchat.vendeur + cible.fee }, 'indemnité payée à l’accord');
    assert.ok(lire(`S.ledger.some(l=>JSON.stringify(l).includes(${JSON.stringify('Indemnité de transfert : ' + cible.name + ' (arrivée le 1er juillet)')}))`), 'ligne de caisse à l’accord');
    assert.deepEqual(r.model.mutations.purchases.map(a => a.playerId), [cible.id]);
    assert.match(marche().candidates.find(c => c.id === cible.id).reason, /^Accord conclu : il rejoindra ton club le 1er juillet 2027\.$/);
    // v2 : rien à une clôture de semaine, même en période ; exécution au changement de saison (achats de settleContracts).
    mutationsOuvertes();
    m = semaine();
    assert.equal(m.squad.some(p => p.id === cible.id), false, 'pas d’arrivée avant le changement de saison');
    const cashExec = lire('club().cash');
    assert.equal(run(`venteExecuterAccords('achats')`), 1);
    m = jeu.call('snapshot');
    assert.ok(m.squad.some(p => p.id === cible.id), 'le joueur a rejoint le club');
    assert.equal(lire(`S.clubs[${cible.clubId}].players.some(p=>p.id==='${cible.id}')`), false);
    assert.equal(lire('club().cash'), cashExec, 'rien de plus à l’arrivée');
    assert.ok(!lire(`S.ledger.some(l=>JSON.stringify(l).includes('Libération anticipée'))`), 'aucune seconde ligne de caisse');
    assert.equal(lire(`S.venteJoueurs.accords.filter(a=>a.sens==='achat').length`), 0);
    assert.equal(lire(`S.venteJoueurs.evenements.filter(e=>e.type==='achat_execute').length`), 1);
    assert.equal(lire('S.budgetTransferts.depense'), avantAchat.dep + cible.fee, 'indemnité engagée une seule fois');
    restaurer();

    // 5. Vente décidée par le président : accord conclu, effectif au changement de saison, rien au budget.
    const pres = lire(`(()=>{const c=club(),res=S.clubBudget.clubs[c.id].reserve;S.presidentReprise={version:1,clubs:{},derniere:{}};
      c.cash=res-1.5e6;const ok=repriseApresAchat(c,res+1e6);const p=S.presidentReprise.clubs[c.id];
      const courrier=repriseCourrier();p.echeance=CDWorldCareer.calendarToday(S);const n=c.players.length,cash=c.cash,r0=S.budgetTransferts.reconstitue;repriseSemaine();
      return {ok,etat:p.etat,mutations:courrier.vars.mutations,n,apres:c.players.length,cash,cashApres:c.cash,r0,accords:S.venteJoueurs.accords.filter(a=>a.imposee).map(a=>({id:a.id,playerId:a.playerId,fee:a.fee,date:a.date}))};})()`);
    jeu.call('save');
    assert.equal(pres.ok, true); assert.equal(pres.etat, 'vendu');
    assert.match(pres.mutations, /^Les transferts prennent effet au changement de saison : .+ le 1er juillet 2027\.$/);
    assert.equal(pres.apres, pres.n, 'le joueur reste jusqu’au changement de saison');
    assert.ok(pres.accords.length >= 1 && pres.accords.every(a => a.date === '2027-07-01'));
    assert.equal(pres.cashApres, pres.cash + pres.accords.reduce((t, a) => t + a.fee, 0), 'ventes du président encaissées à l’accord');
    m = jeu.call('snapshot');
    assert.match(m.sales.pending.find(a => a.id === pres.accords[0].id).label, /^Vente décidée par le président : départ pour .+ le 1er juillet 2027/);
    run(`for(const a of S.venteJoueurs.accords)S.clubs[a.buyer].cash=Math.max(S.clubs[a.buyer].cash,5e6);`);
    const r0 = lire('S.budgetTransferts.reconstitue'), cash0 = lire('club().cash');
    assert.ok(run(`venteExecuterAccords('ventes')`) >= 1);
    m = jeu.call('snapshot');
    for (const a of pres.accords) assert.equal(m.squad.some(p => p.id === a.playerId), false, 'parti à l’ouverture');
    assert.equal(lire('S.budgetTransferts.reconstitue'), r0, 'vente imposée : rien au budget');
    assert.equal(r0, pres.r0, 'rien au budget à l’accord non plus');
    assert.equal(lire('club().cash'), cash0, 'caisse déjà créditée à l’accord');
    restaurer();

    // 6. Part d'une vente choisie rendue sans plafond (R4) : enveloppe déjà au plafond des recettes (vente immédiate :
    // réglage « semaines », ancien comportement, en période).
    run('club().cash=Math.max(club().cash,9e6)');
    R.clubsGeres.calendrier = 'semaines';
    mutationsOuvertes();
    const acheteur = lire(`S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=2e6).id`);
    const vendu = jeu.call('snapshot').squad.find(p => !p.sale.blocked && !p.sale.pending && !p.preContract);
    run(`(()=>{const e=S.budgetTransferts,x=budgetTransfertsEntrees();e.reconstitue=Math.round(x.recettes*nativeBudgetTransferts.REGLAGES.plafond);
      S.economy.offers.push({id:'cal-r4',playerId:'${vendu.id}',buyer:${acheteur},fee:200000,expires:S.economy.week+1});})()`);
    const rec0 = lire('S.budgetTransferts.reconstitue');
    r = jeu.brut('sale_answer', { offerId: 'cal-r4', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.saleAnswer.budgetReturn, Math.round(200000 * T.REGLAGES.partVentes));
    assert.equal(lire('S.budgetTransferts.reconstitue'), rec0 + Math.round(200000 * T.REGLAGES.partVentes));
    const tb = r.model.finance.transferBudget;
    assert.equal(tb.disponible, Math.min(tb.reste, tb.caisseLibre), 'disponible = min(reste, caisse − matelas)');
    restaurer();

    // 7. Pré-contrat du club joué avec un joueur d'un autre club en fin de contrat.
    jeu.regler(jeu.call('snapshot')); // rendez-vous du club réglés avant la décision
    liste = marche();
    const fin = liste.candidates.filter(c => c.preContract && c.contractEnd === lire('S.season'));
    assert.ok(fin.length > 0, 'joueurs en fin de contrat chez les autres clubs');
    assert.ok(fin.every(c => !c.preContract.available), 'pas avant janvier');
    assert.ok(fin.some(c => c.preContract.reason === 'Pré-contrat possible à partir du 1er janvier 2027, à moins de 6 mois de la fin de son contrat.'), fin[0].preContract.reason);
    R.preContrats.moisAvantFin = 12; // contrat de moins de 12 mois : possible dès l'été (période simulée)
    liste = marche();
    const pc = liste.candidates.filter(c => c.preContract?.available).sort((a, b) => a.preContract.premium - b.preContract.premium || (a.id < b.id ? -1 : 1))[0];
    assert.ok(pc, 'pré-contrat possible');
    assert.equal(pc.preContract.arrivalLabel, '1er juillet 2027');
    assert.equal(pc.preContract.premium, K.prime(pc.preContract.salary));
    const avantPc = lire(`({cash:club().cash,dep:S.budgetTransferts.depense,vendeur:S.clubs[${pc.clubId}].cash})`);
    const payload = { playerId: pc.id, sellerId: pc.clubId, salary: pc.preContract.salary, years: 1 };
    assert.equal(jeu.brut('precontract_offer', payload).error, 'Pré-contrat : paramètres invalides.');
    assert.equal(jeu.brut('precontract_offer', { ...payload, confirmed: false }).error, 'Confirme le pré-contrat avant de le proposer.');
    assert.match(jeu.brut('precontract_offer', { ...payload, salary: pc.preContract.salary - 100, confirmed: true }).error, /demande au moins/);
    r = jeu.brut('precontract_offer', { ...payload, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.preContract.arrival, '2027-07-01');
    assert.deepEqual(lire(`({cash:club().cash,dep:S.budgetTransferts.depense,vendeur:S.clubs[${pc.clubId}].cash})`),
      { cash: avantPc.cash - pc.preContract.premium, dep: avantPc.dep + pc.preContract.premium, vendeur: avantPc.vendeur }, 'seule la prime, rien pour le club vendeur');
    assert.equal(lire(`S.clubs[${pc.clubId}].players.some(p=>p.id==='${pc.id}')`), true, 'il reste à son club jusqu’au 1er juillet');
    const candidatSigne = marche().candidates.find(c => c.id === pc.id);
    assert.equal(candidatSigne.reason, 'Pré-contrat signé : il rejoindra ton club le 1er juillet 2027.', 'raison du marché pour un joueur déjà sous pré-contrat avec nous');
    const signe = candidatSigne.preContract;
    assert.equal(signe.available, false); assert.equal(signe.signed.label, 'Rejoindra ' + lire('club().name') + ' le 1er juillet 2027.');
    assert.equal(r.model.mutations.preContracts.arrivals[0].playerId, pc.id);

    // 8. Un autre club approche un joueur du club joué en fin de contrat : courrier, délai, prolongation qui l'annule.
    R.preContrats.approches.chanceSemaine = 1;
    const fins = lire(`(()=>{const ids=club().players.slice().sort((a,b)=>roleNote(b)-roleNote(a)).slice(0,6).map(p=>p.id);for(const p of club().players)if(p.contractEnd===S.season&&!ids.includes(p.id))p.contractEnd=S.season+1;for(const id of ids)player(id).contractEnd=S.season;return ids;})()`);
    jeu.call('save');
    m = semaine();
    let approche = lire(`S.calendrierMutations.preContrats.filter(x=>x.sens==='depart')`);
    assert.equal(approche.length, 1, 'une approche');
    const a1 = approche[0];
    assert.ok(fins.includes(a1.playerId)); assert.equal(a1.etat, 'approche');
    assert.equal(a1.echeance, decaler(a1.date, R.preContrats.approches.delaiJours));
    let fiche = m.squad.find(p => p.id === a1.playerId).preContract;
    assert.equal(fiche.state, 'approche');
    assert.equal(fiche.label, 'Approché par ' + a1.autre + ' : propose-lui une prolongation avant le ' + lire(`nativeVenteJoueurs.dateFr('${a1.echeance}')`) + ', sinon il signera là-bas.');
    const courrier = lire(`calCourriers(S,'approche')`);
    assert.deepEqual(courrier.map(c => c.key), [a1.id + ':approche']);
    assert.equal(courrier[0].player, a1.playerId);
    // Déterminisme : même carrière, même graine → même approche.
    const rejeu = lire(`(()=>{const avant=JSON.stringify(S.calendrierMutations);S.calendrierMutations.preContrats=S.calendrierMutations.preContrats.filter(x=>x.id!=='${a1.id}');
      S.calendrierMutations.seq--;calSemaine();const x=S.calendrierMutations.preContrats.find(y=>y.sens==='depart');const r={playerId:x.playerId,autreId:x.autreId};S.calendrierMutations=JSON.parse(avant);return r;})()`);
    assert.deepEqual(rejeu, { playerId: a1.playerId, autreId: a1.autreId });
    // Prolongation proposée dans le délai : l'autre club renonce.
    const renouv = m.squad.find(p => p.id === a1.playerId).renewal;
    r = jeu.brut('extend_contract', { playerId: a1.playerId, salary: Math.min(100000, Math.ceil(renouv.salary * 1.3 / 100) * 100), years: renouv.minYears, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(lire(`S.calendrierMutations.preContrats.find(x=>x.id==='${a1.id}').etat`), 'annule');
    assert.equal(r.model.squad.find(p => p.id === a1.playerId).preContract, undefined);

    // 9. Seconde approche sans prolongation : il signe à l'échéance ; prolongation et vente refusées ; il reste jusqu'au 1er juillet.
    m = semaine();
    approche = lire(`S.calendrierMutations.preContrats.filter(x=>x.sens==='depart'&&x.etat==='approche')`);
    assert.equal(approche.length, 1, 'seconde approche');
    const a2 = approche[0];
    run(`S.calendrierMutations.preContrats.find(x=>x.id==='${a2.id}').echeance=CDWorldCareer.calendarToday(S)`);
    R.preContrats.approches.chanceSemaine = 0;
    m = semaine();
    fiche = m.squad.find(p => p.id === a2.playerId).preContract;
    assert.equal(fiche.state, 'signe');
    assert.equal(fiche.label, 'A signé à ' + a2.autre + ' : il part libre le 1er juillet 2027.');
    assert.equal(lire(`calCourriers(S,'signe')`)[0].key, a2.id + ':signe');
    const parti = 'A signé un pré-contrat avec ' + a2.autre + ' : il part libre le 1er juillet 2027.';
    const r2 = m.squad.find(p => p.id === a2.playerId).renewal;
    assert.equal(r2.available, false); assert.equal(r2.reason, parti);
    assert.equal(jeu.brut('extend_contract', { playerId: a2.playerId, salary: 100000, years: 1, confirmed: true }).error, parti);
    assert.equal(m.squad.find(p => p.id === a2.playerId).sale.blocked, parti);
    assert.equal(jeu.brut('sale_list', { playerId: a2.playerId, listed: true }).error, parti);
    assert.ok(lire(`S.economy.transfers.some(t=>t.text.startsWith('La presse l’annonce : '))`), 'seule la presse en parle');

    // 10. Bascule de saison (1er juillet) : arrivée et départ, sans indemnité.
    const avantSaison = lire(`({cash:club().cash,vendeur:S.clubs[${pc.clubId}].cash,acheteur:S.clubs[${a2.autreId}].cash})`);
    const accordsVendeur = lire(`(S.calendrierMutations.accordsIA||[]).filter(a=>a.saison===S.season&&a.vendeurId===${pc.clubId}).map(a=>({playerId:a.playerId,acheteurId:a.acheteurId,montant:a.montant}))`);
    const bascule = lire(`(()=>{settleContracts();return {ici:club().players.find(p=>p.id==='${pc.id}')||null,parti:S.clubs[${a2.autreId}].players.find(p=>p.id==='${a2.playerId}')||null,
      libre:S.economy.freeAgents.some(p=>p.id==='${a2.playerId}'),etats:S.calendrierMutations.preContrats.map(x=>[x.id,x.etat]),saison:S.season,
      cash:club().cash,vendeur:S.clubs[${pc.clubId}].cash,acheteur:S.clubs[${a2.autreId}].cash};})()`);
    // Accords des clubs gérés exécutés à la même bascule (autres joueurs du vendeur) : leurs indemnités sont légitimes.
    const ventesVendeur = lire(`(${JSON.stringify(accordsVendeur)}).filter(a=>S.clubs[a.acheteurId].players.some(p=>p.id===a.playerId)).reduce((s,a)=>s+a.montant,0)`);
    assert.ok(bascule.ici, 'le joueur sous pré-contrat a rejoint le club');
    assert.equal(bascule.ici.contractEnd, bascule.saison + 1); assert.equal(bascule.ici.salary, pc.preContract.salary);
    assert.ok(bascule.parti, 'le joueur parti a rejoint son nouveau club');
    assert.ok(bascule.parti.contractEnd > bascule.saison); assert.equal(bascule.libre, false);
    // Les clubs gérés règlent aussi leurs propres fins de contrat à la bascule (primes) : aucune recette d'indemnité.
    assert.ok(bascule.vendeur <= avantSaison.vendeur + ventesVendeur, 'aucune indemnité pour l’ancien club');
    assert.ok(!lire('S.ledger').some(l => JSON.stringify(l).includes(a2.nom)), 'aucune indemnité pour le club joué');
    assert.ok(bascule.etats.filter(([, e]) => e === 'execute').length === 2, JSON.stringify(bascule.etats));
  } finally { restaurer(); jeu.fermer(); }
});

// Plafond de pré-contrats signés par le club joué (preContrats.maxParSaison = 3) : le 4e est refusé, sans rien écrire.
test('Pré-contrats du club joué : trois par saison au plus, le quatrième est refusé avec sa raison', { timeout: 600000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const { lire, run } = outils(jeu);
    assert.equal(R.preContrats.maxParSaison, 3);
    run('club().cash=Math.max(club().cash,9e6)');
    run('(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
    R.preContrats.moisAvantFin = 12;
    const marche = () => lire(`nativeSystems.domain('interclubMarket').project()`);
    const dispo = () => marche().candidates.filter(c => c.preContract?.available).sort((a, b) => a.preContract.premium - b.preContract.premium || (a.id < b.id ? -1 : 1));
    const attendu = 'Tu as déjà signé 3 pré-contrats cette saison (3 au plus) : les suivants attendront la saison prochaine.';
    for (let i = 0; i < 3; i++) {
      const c = dispo()[0];
      assert.ok(c, 'pré-contrat possible n°' + (i + 1));
      const r = jeu.brut('precontract_offer', { playerId: c.id, sellerId: c.clubId, salary: c.preContract.salary, years: 1, confirmed: true });
      assert.equal(r.ok, true, r.error);
    }
    assert.equal(lire(`S.calendrierMutations.preContrats.filter(x=>x.sens==='arrivee'&&x.etat==='signe').length`), 3);
    const quatre = marche().candidates.filter(c => c.contractEnd === lire('S.season') && c.preContract && !c.preContract.signed);
    assert.ok(quatre.length > 0);
    assert.ok(quatre.every(c => c.preContract.available === false));
    assert.ok(quatre.some(c => c.preContract.reason === attendu), quatre[0].preContract.reason);
    // Aucun joueur n'est plus proposé : essayer le meilleur marché d'avant le plafond (salaire demandé relevé).
    const cible = quatre.find(c => c.preContract.reason === attendu);
    const avant = lire('({cash:club().cash,dep:S.budgetTransferts.depense,n:S.calendrierMutations.preContrats.length,seq:S.calendrierMutations.seq,led:S.ledger.length})');
    const r4 = jeu.brut('precontract_offer', { playerId: cible.id, sellerId: cible.clubId, salary: 100000, years: 1, confirmed: true });
    assert.equal(r4.ok, false); assert.equal(r4.error, attendu);
    assert.deepEqual(lire('({cash:club().cash,dep:S.budgetTransferts.depense,n:S.calendrierMutations.preContrats.length,seq:S.calendrierMutations.seq,led:S.ledger.length})'), avant, 'le refus n’écrit rien');
    // Le plafond est un réglage : à 4, le quatrième repasse.
    R.preContrats.maxParSaison = 4;
    assert.ok(dispo().length > 0, 'quatrième possible avec un plafond de 4');
  } finally { restaurer(); jeu.fermer(); }
});

// Temps de clôture de semaine (cadence hebdomadaire) avec une approche tirée chaque semaine (six joueurs en fin de
// contrat, pré-contrats possibles), comparé à la même clôture sans approche. Seuil : +1,5 s, toujours sous 15 s.
const SURCOUT_MAX_MS = 1500;
test('Performance : clôture de semaine avec approches de pré-contrat', { timeout: 600000 }, () => {
  const mesure = approches => {
    const jeu = ouvrir({ hebdomadaire: true, testVm: true });
    try {
      creer(jeu, CLUB);
      const { run, semaine } = outils(jeu);
      if (approches) {
        R.preContrats.moisAvantFin = 12; R.preContrats.approches.chanceSemaine = 1; R.preContrats.approches.maxParSaison = 99;
        run(`for(const p of club().players.slice(0,6))p.contractEnd=S.season`);
      } else R.preContrats.approches.actives = false;
      semaine();
      const t = [];
      for (let k = 0; k < 2; k++) { const d = Date.now(); semaine(); t.push(Date.now() - d); }
      const n = JSON.parse(jeu.bridge.vm.run(`JSON.stringify((S.calendrierMutations?.preContrats||[]).length)`));
      return { ms: Math.min(...t), n };
    } finally { restaurer(); jeu.fermer(); }
  };
  const sans = mesure(false), avec = mesure(true);
  console.log(`clôture de semaine : sans approche ${sans.ms} ms, avec approches ${avec.ms} ms (${avec.n} approches)`);
  assert.equal(sans.n, 0); assert.ok(avec.n >= 2, 'approches tirées : ' + avec.n);
  assert.ok(avec.ms - sans.ms <= SURCOUT_MAX_MS, `surcoût ${avec.ms - sans.ms} ms > ${SURCOUT_MAX_MS} ms`);
  assert.ok(avec.ms < 15000);
});

// Encaissement à l'accord (décision de Léo du 20/11/2026, budget-transferts.md R4) : la part d'une vente choisie revient
// à l'enveloppe le jour de l'accord ; à la bascule, seul un achat qui tombe encore (joueur disparu) rend son indemnité, à
// l'enveloppe de la saison qui commence (pas à la saison close, où le report R5 n'en aurait passé qu'une partie).
test('Bascule : part d’une vente rendue à l’accord, achat tombé rendu à la nouvelle saison', { timeout: 600000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const { lire, run } = outils(jeu);
    run('club().cash=Math.max(club().cash,9e6)');
    const acheteur = lire(`S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=2e6).id`);
    const vendu = jeu.call('snapshot').squad.find(p => !p.sale.blocked && !p.sale.pending && !p.preContract);
    run(`S.economy.offers.push({id:'bascule-r4',playerId:'${vendu.id}',buyer:${acheteur},fee:400000,expires:S.economy.week+1});`);
    const r0 = lire('S.budgetTransferts.reconstitue');
    const r = jeu.brut('sale_answer', { offerId: 'bascule-r4', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    const part = Math.round(400000 * T.REGLAGES.partVentes);
    assert.ok(lire(`S.venteJoueurs.accords.some(a=>a.playerId==='${vendu.id}'&&a.bascule&&a.paye)`), 'accord payé, exécuté au 1er juillet');
    assert.equal(lire('S.budgetTransferts.reconstitue'), r0 + part, 'part de la vente rendue le jour de l’accord');
    // Achat conclu et payé dont le joueur a disparu avant la bascule : il tombe, l'indemnité est rendue.
    run(`(()=>{const e=budgetTransfertsEtat(true);e.depense=Math.round(e.depense+150000);ledgerEntry('Indemnité de transfert : Joueur parti (arrivée le 1er juillet)',-150000);S.clubs[${acheteur}].cash+=150000;
      S.venteJoueurs.seq++;S.venteJoueurs.accords.push({id:'achat-test',sens:'achat',clubId:S.club,playerId:'absent-test',joueur:'Joueur parti',seller:${acheteur},vendeur:'Vendeur',fee:150000,saison:S.season,date:'2027-07-01',bascule:true,paye:true});})()`);
    const avant = lire('({...S.budgetTransferts})');
    run('settleContracts()');
    const close = lire('({...S.budgetTransferts})');
    assert.equal(lire(`club().players.some(p=>p.id==='${vendu.id}')`), false, 'le joueur est parti');
    assert.equal(close.reconstitue, avant.reconstitue, 'rien de plus pour la vente à la bascule');
    assert.equal(close.depense, avant.depense, 'l’indemnité rendue ne va pas à la saison close');
    assert.equal(close.aNouvelleSaison, 150000);
    assert.ok(lire(`S.ledger.some(l=>JSON.stringify(l).includes('Indemnité rendue : Joueur parti'))`), 'ligne de caisse du remboursement');
    const neuve = lire(`(()=>{const s=S.season;S.season=s+1;try{return budgetTransfertsNeuf();}finally{S.season=s;}})()`);
    assert.equal(neuve.reconstitue, 150000, 'l’indemnité rendue passe à l’enveloppe de la nouvelle saison');
    assert.equal(neuve.depense, 0);
    assert.equal(neuve.report, T.report(close, neuve.enveloppe, lire('budgetTransfertsEntrees().recettes')), 'le report ne compte pas cet argent deux fois');
  } finally { restaurer(); jeu.fermer(); }
});

// Liste des accords entre clubs gérés bornée (accordsGardes) : un accord payé et en attente n'est jamais supprimé, seuls les
// accords d'une saison passée le sont (sinon l'argent déjà passé à l'accord serait perdu avec le transfert).
test('Accords payés en attente : jamais écartés par la borne de la liste', { timeout: 600000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const { lire, run } = outils(jeu);
    const borne = R.clubsGeres.accordsGardes;
    const n = borne + 40;
    run(`(()=>{const st=calIAEtat();st.accordsIA=[];
      for(let i=0;i<${n};i++)st.accordsIA.push({id:'faux-'+i,playerId:'faux'+i,nom:'Faux '+i,pos:'1',vendeurId:1,vendeur:'V',acheteurId:2,acheteur:'A',montant:1000,salaire:1000,annees:1,date:'',saison:S.season,paye:true});
      st.accordsIA.unshift({id:'vieux',playerId:'vieux',nom:'Vieux',pos:'1',vendeurId:1,vendeur:'V',acheteurId:2,acheteur:'A',montant:1,salaire:1,annees:1,date:'',saison:S.season-1,paye:true});
      const s=S.clubs.find(c=>c.id!==S.club),b=S.clubs.find(c=>c.id!==S.club&&c.id!==s.id);
      calIANouvelAccord(b,s,s.players[0],1000,1000,1);})()`);
    const ids = lire('S.calendrierMutations.accordsIA.map(a=>a.id)');
    for (let i = 0; i < n; i++) assert.ok(ids.includes('faux-' + i), 'accord payé en attente conservé : faux-' + i);
    assert.equal(ids.length, n + 1, 'les accords en attente et le nouveau restent ; l’accord de la saison passée est écarté');
    assert.equal(ids.includes('vieux'), false, 'l’accord de la saison passée est écarté');
  } finally { restaurer(); jeu.fermer(); }
});

// Décisions de Léo du 20/11/2026 (GDD calendrier-mutations § 3, § 3 quater) : vente conclue en octobre encaissée le jour
// même ; achat payé à l'accord ; place de la saison suivante vérifiée à l'accord ; retraite annoncée à la première clôture
// de janvier (période simulée) puis refus d'achat, de vente et de pré-contrat ; un joueur engagé avant l'annonce ne prend
// pas sa retraite et rejoint son club.
test('Encaissement à l’accord, place réservée, retraite annoncée', { timeout: 900000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  const RETRAITE = 'A annoncé qu’il arrêtera sa carrière à la fin de la saison.';
  try {
    creer(jeu, CLUB);
    const { lire, run, jour, semaine } = outils(jeu);
    run('club().cash=Math.max(club().cash,9e6)');
    run('(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
    const octobre = jour().slice(0, 4) + '-10-01';
    for (let k = 0; k < 12 && jour() < octobre; k++) semaine();
    assert.equal(jour().slice(5, 7), '10', 'octobre : ' + jour());
    run('club().cash=Math.max(club().cash,9e6)');

    // 1. Vente conclue en octobre : caisse +montant et budget +50 % le jour même ; joueur présent jusqu'à la bascule.
    const acheteur = lire(`S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=3e6).id`);
    const vendu = jeu.call('snapshot').squad.find(p => !p.sale.blocked && !p.sale.pending && !p.preContract);
    run(`S.economy.offers.push({id:'oct',playerId:'${vendu.id}',buyer:${acheteur},fee:300000,expires:S.economy.week+1});`);
    const av = lire(`({cash:club().cash,rec:S.budgetTransferts.reconstitue,b:S.clubs[${acheteur}].cash})`);
    let r = jeu.brut('sale_answer', { offerId: 'oct', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    const part = Math.round(300000 * T.REGLAGES.partVentes);
    assert.deepEqual(lire(`({cash:club().cash,rec:S.budgetTransferts.reconstitue,b:S.clubs[${acheteur}].cash})`), { cash: av.cash + 300000, rec: av.rec + part, b: av.b - 300000 });
    assert.ok(lire(`S.ledger.some(l=>JSON.stringify(l).includes(${JSON.stringify('Vente : ' + vendu.name + ' (départ le 1er juillet)')}))`));
    assert.ok(r.model.squad.some(p => p.id === vendu.id), 'il reste jusqu’à la bascule');

    // 2. Achat payé à l'accord, d'un joueur qui devait arrêter à la fin de la saison (engagé avant l'annonce).
    const marche = () => lire(`nativeSystems.domain('interclubMarket').project()`);
    let liste = marche();
    const cible = liste.candidates.filter(c => c.available && c.fee <= 400000 && c.contractEnd > lire('S.season')).sort((a, b) => a.fee - b.fee || (a.id < b.id ? -1 : 1))[0];
    assert.ok(cible, 'joueur sous contrat abordable');
    run(`(()=>{const p=S.clubs[${cible.clubId}].players.find(q=>q.id==='${cible.id}');ensureDevelopment(p);p.dev.retireAge=p.age+1;})()`);
    const avA = lire(`({cash:club().cash,vendeur:S.clubs[${cible.clubId}].cash})`);
    r = jeu.brut('interclub_transfer', { playerId: cible.id, sellerId: cible.clubId, fee: cible.fee, salary: cible.salary, sourceSalary: cible.sourceSalary, contractEnd: cible.contractEnd, context: liste.context, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.deepEqual(lire(`({cash:club().cash,vendeur:S.clubs[${cible.clubId}].cash})`), { cash: avA.cash - cible.fee, vendeur: avA.vendeur + cible.fee });
    assert.ok(lire(`S.ledger.some(l=>JSON.stringify(l).includes(${JSON.stringify('Indemnité de transfert : ' + cible.name + ' (arrivée le 1er juillet)')}))`));
    const engage = lire(`(()=>{const p=S.clubs[${cible.clubId}].players.find(q=>q.id==='${cible.id}');return {age:p.age,retireAge:p.dev.retireAge};})()`);
    assert.ok(engage.retireAge >= engage.age + (cible.contractEnd - lire('S.season')) + 1, 'retraite repoussée après son nouveau contrat');

    // 3. Place de la saison suivante vérifiée à l'accord (capacité ramenée à l'effectif prévu) : raison exacte.
    const plein = lire(`(()=>{const s=calIASuivante(club());globalThis.__cap=professionalCapacity;professionalCapacity=function(c,x){return (c||club()).id===S.club?s.n:__cap.apply(this,arguments);};return s.n;})()`);
    try {
      const raison = 'Ton effectif de la saison prochaine est déjà complet (' + plein + '/' + plein + ' avec les arrivées prévues)';
      liste = marche();
      const c2 = liste.candidates.find(c => c.reason === raison);
      assert.ok(c2, 'raison écrite sur le marché : ' + liste.candidates.slice(0, 3).map(c => c.reason).join(' | '));
      assert.equal(jeu.brut('interclub_transfer', { playerId: c2.id, sellerId: c2.clubId, fee: c2.fee, salary: c2.salary, sourceSalary: c2.sourceSalary, contractEnd: c2.contractEnd, context: liste.context, confirmed: true }).error, 'Marché entre clubs : ' + raison + '.');
    } finally { run('professionalCapacity=__cap'); }

    // 4. Retraite annoncée à la première clôture de la période (1er janvier, simulée aujourd'hui).
    const p1 = lire(`(()=>{const p=club().players.find(q=>q.id!=='${vendu.id}'&&!venteRaisonListe(q)&&q.contractEnd>S.season);ensureDevelopment(p);p.dev.retireAge=p.age+1;return {id:p.id,name:p.name};})()`);
    liste = marche();
    const p2 = liste.candidates.find(c => c.available && c.id !== cible.id && c.contractEnd > lire('S.season'));
    run(`(()=>{const p=S.clubs[${p2.clubId}].players.find(q=>q.id==='${p2.id}');ensureDevelopment(p);p.dev.retireAge=p.age+1;})()`);
    R.retraites = { periodes: [{ debut: md(jour()), fin: md(decaler(jour(), 30)) }] };
    let m = semaine();
    assert.ok(lire('S.news').includes(p1.name + ' annonce qu’il arrêtera sa carrière à la fin de la saison.'), 'actualité');
    assert.equal(m.squad.find(p => p.id === p1.id).sale.blocked, RETRAITE);
    assert.equal(jeu.brut('sale_list', { playerId: p1.id, listed: true }).error, RETRAITE);
    run(`S.economy.offers.push({id:'retraite',playerId:'${p1.id}',buyer:${acheteur},fee:100000,expires:S.economy.week+1});`);
    assert.equal(jeu.brut('sale_answer', { offerId: 'retraite', action: 'accept', confirmed: true }).error, RETRAITE);
    liste = marche();
    const c3 = liste.candidates.find(c => c.id === p2.id);
    assert.equal(c3.reason, RETRAITE.slice(0, -1));
    assert.equal(jeu.brut('interclub_transfer', { playerId: c3.id, sellerId: c3.clubId, fee: c3.fee, salary: c3.salary, sourceSalary: c3.sourceSalary, contractEnd: c3.contractEnd, context: liste.context, confirmed: true }).error, 'Marché entre clubs : ' + RETRAITE);
    assert.equal(jeu.brut('precontract_offer', { playerId: c3.id, sellerId: c3.clubId, salary: 50000, years: 1, confirmed: true }).error, RETRAITE);
    assert.equal(lire(`S.clubs[${cible.clubId}].players.find(q=>q.id==='${cible.id}').dev.annonceRetraite??null`), null, 'le joueur engagé n’annonce rien');

    // 5. Bascule : le joueur engagé avant l'annonce ne prend pas sa retraite et rejoint le club ; le vendu part.
    const b = lire(`(()=>{rollDevelopmentYear();settleContracts();return {ici:club().players.some(p=>p.id==='${cible.id}'),vendu:S.clubs[${acheteur}].players.some(p=>p.id==='${vendu.id}'),
      retraite:S.development.retired.some(x=>x.id==='${cible.id}')};})()`);
    assert.equal(b.retraite, false, 'pas de retraite avant la fin du nouveau contrat');
    assert.equal(b.ici, true, 'il rejoint le club');
    assert.equal(b.vendu, true, 'le joueur vendu a rejoint son acheteur');
  } finally { restaurer(); jeu.fermer(); }
});