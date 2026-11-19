'use strict';
// Vente de joueurs (native/engine/vente-joueurs.cjs, docs/gdd/vente-joueurs.md) : mise en liste et retrait, blocages,
// offres à la clôture de semaine, offres spontanées, réponses (accepter, demander plus au millier, refuser),
// expiration, garde d'effectif, période des mutations (accord conclu hors période, exécuté ou qui tombe à l'ouverture),
// passage de saison, budget de transferts (+50 %), courrier, correction de coût (même résultat) et temps de clôture.
// Mode Monde uniquement (`world-champ`, club 102).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const V = require('../native/engine/vente-joueurs.cjs');
const R = require('../native/engine/vente-joueurs.json');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('./helpers/carriere-monde.cjs');

const CLUB = 102;
const copie = x => JSON.parse(JSON.stringify(x));
const REGLAGES = copie(R);
// Réglages modifiés le temps d'un test (le moteur lit le même objet JSON, dans le même processus).
const regler = (modif) => { modif(R); };
const restaurer = () => { for (const k of Object.keys(REGLAGES)) R[k] = copie(REGLAGES[k]); };
const outils = jeu => {
  const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
  // Retouche de la carrière suivie d'une sauvegarde (une commande refuse une carrière modifiée hors commande).
  const run = s => { const r = jeu.bridge.vm.run(s); jeu.call('save'); return r; };
  const jour = () => lire('CDWorldCareer.calendarToday(S)');
  // Période des mutations ouverte autour d'aujourd'hui (ou qui ouvre dans `dans` jours).
  const periode = (dans = 0, duree = 20) => {
    const d0 = new Date(Date.parse(jour() + 'T00:00:00Z') + dans * 86400000), d1 = new Date(d0.getTime() + duree * 86400000);
    regler(r => { r.fenetres.mode = 'fenetres'; r.fenetres.periodes = [{ debut: d0.toISOString().slice(5, 10), fin: d1.toISOString().slice(5, 10) }]; });
    return d0.toISOString().slice(0, 10);
  };
  // Clôt la semaine (match du club joué délégué s'il y en a un).
  const semaine = () => { const m = jeu.regler(jeu.call('snapshot')); return m.next ? jouerLeMatch(jeu, m) : jeu.regler(jeu.call('finish_round')); };
  return { lire, run, jour, periode, semaine };
};
// Offre fabriquée dans la carrière (même forme que celles d'economyWeek).
const offrir = (run, id, playerId, buyer, fee, extra = '') => run(`S.economy.offers.push({id:'${id}',playerId:'${playerId}',buyer:${buyer},fee:${fee},expires:S.economy.week+1${extra}})`);

test('Formules : relance au millier, plafond, période des mutations, tirage des offres spontanées', () => {
  try {
    assert.equal(V.relance(60000, 5), 63000, 'au millier, pas à 10 000 €');
    assert.equal(V.relance(60000, 10), 66000);
    assert.equal(V.relance(61234, 15), 71000, 'arrondi au millier supérieur');
    // GDD : besoin 20, caisse 2 M€ → plafond min(1 650 000, 60 000 × 1,12) = 67 000 au millier.
    assert.equal(V.plafond(60000, 2e6, 20), 67000);
    assert.equal(V.plafond(60000, 400000, 60), 50000, 'réserve de caisse de l’acheteur');
    // Règlement LNR : cessions du 1er mai au 30 juin.
    assert.deepEqual(V.fenetre('2026-08-17'), { mode: 'fenetres', ouverte: false, reouverture: '2027-05-01', raison: 'Hors période des mutations : une vente acceptée sera effective le 1er mai 2027.' });
    assert.equal(V.fenetre('2027-05-01').ouverte, true);
    assert.equal(V.fenetre('2027-06-30').ouverte, true);
    assert.equal(V.fenetre('2027-07-01').reouverture, '2028-05-01');
    assert.equal(V.fenetre('2027-02-10').reouverture, '2027-05-01');
    assert.equal(V.fenetre('2027-12-20', { fenetres: { mode: 'fenetres', periodes: [{ debut: '12-15', fin: '01-31' }] } }).ouverte, true, 'période à cheval sur le 1er janvier');
    assert.equal(V.fenetre('2027-01-20', { fenetres: { mode: 'fenetres', periodes: [{ debut: '12-15', fin: '01-31' }] } }).ouverte, true);
    assert.equal(V.fenetre('2026-08-17', { fenetres: { mode: 'saison', periodes: [] } }).ouverte, true, 'réglage « saison »');
    // Tirage déterministe, plafonné par saison, jamais avant semaineMin.
    const tirees = g => Array.from({ length: 45 }, (_, w) => V.semaineTiree(g, 2026, w)).map((x, w) => x ? w : -1).filter(w => w >= 0);
    assert.deepEqual(tirees(4242), tirees(4242));
    for (const g of [1, 4242, 99999, 123456789]) { const t = tirees(g); assert.ok(t.length <= R.spontanees.maxParSaison && t.every(w => w >= R.spontanees.semaineMin), g + ' : ' + t); }
    assert.ok([1, 4242, 99999, 123456789, 7, 8].some(g => tirees(g).length > 0), 'quelques offres par saison');
    // Changer le JSON change le jeu sans toucher au code.
    regler(r => { r.relances.arrondi = 10000; });
    assert.equal(V.relance(60000, 5), 70000);
    regler(r => { r.spontanees.chanceSemaine = 1; r.spontanees.semaineMin = 0; r.spontanees.maxParSaison = 2; });
    assert.deepEqual(tirees(4242), [0, 1]);
  } finally { restaurer(); }
});

test('Moteur Monde : liste, blocages, offres, spontanées, réponses, garde, période des mutations, saison, courrier', { timeout: 900000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let m = creer(jeu, CLUB);
    const { lire, run, jour, periode, semaine } = outils(jeu);
    const libres = m.squad.filter(p => !p.sale.blocked && !p.sale.listed);
    assert.ok(m.squad.length >= 40, 'effectif ' + m.squad.length);
    assert.deepEqual(Object.keys(m.squad[0].sale).sort(), ['blocked', 'listed', 'offerId', 'pending', 'value']);
    assert.equal(m.sales.available, true); assert.equal(m.sales.minimum, 37);
    assert.equal(m.sales.window.open, false, 'août : hors période des mutations');
    assert.equal(m.sales.window.reopensLabel, '1er mai 2027');

    // 1. Paramètres invalides et blocages écrits.
    for (const payload of [{ playerId: libres[0].id }, { playerId: libres[0].id, listed: 'oui' }, { playerId: libres[0].id, listed: true, x: 1 }]) {
      const r = jeu.brut('sale_list', payload); assert.equal(r.ok, false); assert.equal(r.error, 'Paramètres de mise en vente invalides.');
    }
    assert.equal(jeu.brut('sale_list', { playerId: 'inconnu', listed: true }).error, 'Ce joueur ne fait pas partie de ton effectif.');
    const recrue = libres[libres.length - 1];
    run(`(()=>{const p=player('${recrue.id}');p.joinedSeason=S.season;p.joinedRound=S.round;})()`);
    m = jeu.call('snapshot');
    const raisonRecrue = 'Nouvelle recrue : attends trois journées avant de la revendre.';
    assert.equal(m.squad.find(p => p.id === recrue.id).sale.blocked, raisonRecrue);
    assert.equal(jeu.brut('sale_list', { playerId: recrue.id, listed: true }).error, raisonRecrue);

    // 2. Mise en liste puis retrait (le retrait efface l'offre en cours).
    const [a, b, c] = libres;
    let r = jeu.brut('sale_list', { playerId: a.id, listed: true });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.meta.saleList.listed, true);
    assert.equal(r.model.squad.find(p => p.id === a.id).sale.listed, true);
    assert.deepEqual(r.model.sales.listed.map(x => x.playerId), [a.id]);
    offrir(run, 'test-retrait', a.id, 5, 50000);
    r = jeu.brut('sale_list', { playerId: a.id, listed: false });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.sales.listed.length, 0);
    assert.equal(r.model.sales.offers.some(o => o.playerId === a.id), false, 'offre effacée au retrait');
    for (const p of [a, b, c]) assert.equal(jeu.brut('sale_list', { playerId: p.id, listed: true }).ok, true);

    // 3. Correction de coût : mêmes offres, même carrière, avec et sans mémoire des besoins (semaine à offre spontanée).
    regler(x => { x.spontanees.chanceSemaine = 1; x.spontanees.semaineMin = 0; x.spontanees.maxParSaison = 99; });
    // Horloge du moteur figée : temps mesurés ici, autour de chaque appel.
    const vm = jeu.bridge.vm, chrono = s => { const d = performance.now(); vm.run(s); return performance.now() - d; };
    vm.run('globalThis.__venteReel=S;globalThis.__venteTexte=JSON.stringify(S);');
    const egalite = { t: {} };
    egalite.t.sans = chrono('S=JSON.parse(__venteTexte);nativeVenteMemo=false;economyWeek();globalThis.__venteSans=JSON.stringify(S);');
    egalite.t.avec = chrono('S=JSON.parse(__venteTexte);nativeVenteMemo=true;economyWeek();globalThis.__venteAvec=JSON.stringify(S);');
    Object.assign(egalite, lire('({meme:__venteSans===__venteAvec,offres:S.economy.offers.length,sp:S.economy.offers.filter(o=>o.spontaneous).length})'));
    vm.run('S=__venteReel;delete globalThis.__venteReel;delete globalThis.__venteTexte;delete globalThis.__venteSans;delete globalThis.__venteAvec;');
    assert.equal(egalite.meme, true, 'même résultat avec la mémoire');
    assert.ok(egalite.offres >= 3 && egalite.sp === 1, JSON.stringify(egalite));
    assert.ok(egalite.t.avec * 3 < egalite.t.sans, 'mémoire au moins 3 fois plus rapide : ' + JSON.stringify(egalite.t));
    restaurer();

    // 4. Offres générées à la clôture de la semaine, pour chaque joueur proposé ; courrier « offre_transfert ».
    m = semaine();
    for (const p of [a, b, c]) {
      const o = m.sales.offers.find(x => x.playerId === p.id);
      assert.ok(o, 'offre pour ' + p.name);
      assert.ok(o.fee >= 20000 && o.buyerId !== CLUB && o.weeksLeft === 1 && o.spontaneous === false && o.listed === true);
      assert.equal(m.squad.find(x => x.id === p.id).sale.offerId, o.id);
      assert.deepEqual(o.counter.percents, [5, 10, 15]);
      assert.equal(o.accept.available, true, o.accept.reason);
      assert.equal(o.deferred.dateLabel, '1er mai 2027');
      assert.equal(o.squadAfter, m.squad.length - 1); assert.equal(typeof o.jiff, 'string');
    }
    const courriers = lire('venteCourriers(S)');
    assert.deepEqual(courriers.map(x => x.key).sort(), m.sales.offers.map(o => o.id).sort());
    assert.match(courriers[0].vars.montant, /^\d[\d ]* €$/);

    // 5. Demander plus : montant au millier ; l'acheteur relève ou se retire selon son plafond ; une seule fois.
    const oa = m.sales.offers.find(x => x.playerId === a.id);
    run(`S.clubs[${oa.buyerId}].cash=5e7`);
    const attendu = V.relance(oa.fee, 5), besoin = lire(`venteBesoin(S.clubs[${oa.buyerId}],player('${a.id}'))`);
    r = jeu.brut('sale_answer', { offerId: oa.id, action: 'counter', percent: 5 });
    assert.equal(r.ok, true, r.error);
    const releve = attendu <= V.plafond(oa.fee, 5e7, besoin);
    assert.equal(r.model.meta.saleAnswer.raised, releve); assert.equal(r.model.meta.saleAnswer.fee, attendu);
    assert.equal(attendu % 1000, 0);
    if (releve) {
      const o2 = r.model.sales.offers.find(x => x.id === oa.id);
      assert.equal(o2.fee, attendu); assert.equal(o2.countered, 5); assert.equal(o2.counter.available, false);
      assert.match(r.model.meta.saleAnswer.message, /relève son offre/);
      assert.equal(jeu.brut('sale_answer', { offerId: oa.id, action: 'counter', percent: 10 }).error, 'Tu as déjà demandé plus : accepte ou refuse cette offre.');
    } else assert.match(r.model.meta.saleAnswer.message, /retire son offre/);
    // Acheteur à court : hausse de 15 % au-delà du plafond → retrait, message écrit.
    const ob = m.sales.offers.find(x => x.playerId === b.id);
    run(`S.clubs[${ob.buyerId}].cash=${ob.fee + 360000}`);
    r = jeu.brut('sale_answer', { offerId: ob.id, action: 'counter', percent: 15 });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.meta.saleAnswer.raised, false);
    assert.equal(r.model.sales.offers.some(x => x.id === ob.id), false);
    assert.equal(jeu.brut('sale_answer', { offerId: ob.id, action: 'counter', percent: 7 }).error, 'Hausse demandée invalide : +5 %, +10 %, +15 %.');

    // 6. Refus : l'offre disparaît, le joueur reste proposé.
    const oc = m.sales.offers.find(x => x.playerId === c.id);
    r = jeu.brut('sale_answer', { offerId: oc.id, action: 'decline' });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.sales.offers.some(x => x.id === oc.id), false);
    assert.equal(r.model.squad.find(x => x.id === c.id).sale.listed, true);

    // 7. Accepter sans confirmation : refusé. Hors période : accord conclu, le joueur reste et joue jusqu'au 1er mai.
    const oa2 = r.model.sales.offers.find(x => x.playerId === a.id) || (offrir(run, 'test-a', a.id, 7, 80000), jeu.call('snapshot').sales.offers.find(x => x.id === 'test-a'));
    assert.equal(jeu.brut('sale_answer', { offerId: oa2.id, action: 'accept' }).error, 'Confirme la vente avant de l’accepter.');
    const caisse0 = lire('club().cash'), n0 = lire('club().players.length');
    r = jeu.brut('sale_answer', { offerId: oa2.id, action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.saleAnswer.deferred, true); assert.equal(r.model.meta.saleAnswer.date, '2027-05-01');
    assert.equal(lire('club().cash'), caisse0, 'argent à l’exécution seulement'); assert.equal(lire('club().players.length'), n0);
    const pa = r.model.squad.find(x => x.id === a.id).sale;
    assert.equal(pa.listed, false); assert.equal(pa.pending.date, '2027-05-01');
    assert.match(pa.pending.label, /^Vente en attente : départ pour .+ le 1er mai 2027/);
    assert.match(pa.blocked, /^Vente conclue avec .+ : départ le 1er mai 2027\.$/);
    assert.deepEqual(r.model.sales.pending.map(x => x.playerId), [a.id]);

    // 8. Accord exécuté à l'ouverture de la période : caisse +montant, joueur parti, ligne de caisse, 50 % au budget.
    const ouverture = periode(3);
    const accordId = lire('S.venteJoueurs.accords[0].id');
    run(`S.venteJoueurs.accords[0].date='${ouverture}';S.budgetTransferts.reconstitue=0;S.budgetTransferts.enveloppe=Math.min(S.budgetTransferts.enveloppe,500000)`);
    const fee = lire('S.venteJoueurs.accords[0].fee'), recettes = lire('budgetTransfertsEntrees().recettes'), env = lire('S.budgetTransferts');
    m = semaine();
    assert.ok(jour() >= ouverture);
    assert.equal(m.squad.some(x => x.id === a.id), false, 'joueur parti');
    assert.equal(lire('S.venteJoueurs.accords.length'), 0);
    assert.ok(lire(`S.ledger.some(l=>JSON.stringify(l).includes('Vente : ${a.name.replace(/'/g, "\\'")}'))`), 'ligne de caisse « Vente : Nom »');
    assert.equal(lire('S.budgetTransferts.reconstitue'), require('../native/engine/budget-transferts.cjs').rendu(env, fee, recettes), '50 % rendus à l’enveloppe');
    assert.ok(lire('S.budgetTransferts.reconstitue') > 0);
    const ev = lire('S.venteJoueurs.evenements').find(e => e.type === 'executee');
    assert.ok(ev && ev.playerId === a.id && ev.montant === fee);
    assert.equal(lire(`venteCourriersAccords(S,'executee',CDWorldCareer.calendarToday(S))`)[0].key, ev.id);
    assert.notEqual(ev.id, accordId);

    // 9. Pendant la période : exécution immédiate (caisse, effectif, budget), feuille vérifiée.
    periode(0, 30);
    run('S.budgetTransferts.reconstitue=0');
    const d = m.squad.filter(p => !p.sale.blocked && !p.sale.listed && !p.sale.pending)[0];
    const acheteur = lire(`S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=2e6).id`);
    offrir(run, 'test-direct', d.id, acheteur, 150000);
    const avant = lire('({cash:club().cash,n:club().players.length})');
    // Part rendue : 50 % de la vente, plafonnée par la règle du budget (enveloppe + report + reconstitué ≤ recettes × plafond).
    const renduAttendu = require('../native/engine/budget-transferts.cjs').rendu(lire('S.budgetTransferts'), 150000, lire('budgetTransfertsEntrees().recettes'));
    assert.ok(renduAttendu > 0 && renduAttendu <= 75000, 'part rendue : ' + renduAttendu);
    m = jeu.call('snapshot');
    const od = m.sales.offers.find(x => x.id === 'test-direct');
    assert.equal(od.deferred, null); assert.equal(od.squadAfter, avant.n - 1); assert.equal(od.cashAfter, avant.cash + 150000);
    assert.equal(od.fillers, Math.max(0, 40 - (avant.n - 1)), 'joueurs de complément annoncés (plancher de 40)');
    r = jeu.brut('sale_answer', { offerId: 'test-direct', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    const sa = r.model.meta.saleAnswer;
    assert.equal(sa.deferred, undefined); assert.equal(sa.fee, 150000); assert.equal(sa.squadSize, avant.n - 1);
    assert.equal(lire('club().cash'), avant.cash + 150000);
    assert.equal(sa.budgetReturn, renduAttendu); assert.equal(lire('S.budgetTransferts.reconstitue'), renduAttendu);
    const espaces = s => s.replace(/[\s  ]+/g, ' ');
    assert.ok(espaces(sa.message).endsWith(`pour 150 000 €. ${renduAttendu.toLocaleString('fr-FR').replace(/[\s  ]+/g, ' ')} € reviennent au budget de transferts. Vérifie ta feuille à 23.`), sa.message);
    assert.equal(lire(`S.clubs[${acheteur}].players.some(p=>p.id==='${d.id}')`), true);
    assert.ok(lire('S.ledger').some(l => JSON.stringify(l).includes('Vente : ')), 'ligne de caisse');

    // 9 bis. Conséquences légères d'un départ important (jauges existantes, valeurs du JSON), annoncées avant la vente :
    // le leader du vestiaire part, un coéquipier lié par un duo perd de la satisfaction, le groupe du moral, les
    // supporters de la confiance ; la caisse étant sous la réserve, le président apprécie.
    const C = R.consequences;
    const prep = lire(`(()=>{const l=CDRelationsV70.leader(S);
      // Deux renforts à son poste (venus d'un autre club) : la garde d'effectif ne bloque pas ce départ.
      const autre=S.clubs.find(c=>c.id!==S.club&&c.id!==${acheteur}&&c.players.filter(q=>q.fam===l.fam&&q.pos===l.pos).length>=4);
      for(let k=0;k<2;k++){const q=autre.players.find(x=>x.fam===l.fam&&x.pos===l.pos);autre.players=autre.players.filter(x=>x!==q);club().players.push(q);
        if(typeof ensureSatisfaction==='function')ensureSatisfaction(q);if(q.satisfaction)q.satisfaction.score=45;} // pas candidats au rôle de leader
      const t=club().players.find(q=>q.id!==l.id&&!q.injury);if(typeof ensureSatisfaction==='function')ensureSatisfaction(t);
      const k=[l.id,t.id].sort().join('|');S.v70Relations={version:1,last:S.season+':'+S.economy.week,pairs:[{key:k,a:[l.id,t.id].sort()[0],b:[l.id,t.id].sort()[1],score:20,season:S.season,week:S.economy.week}]};
      club().cash=S.clubBudget.clubs[S.club].reserve-1;S.morale=70;S.trust=50;if(S.pressRelations)S.pressRelations.fanTrust=50;t.satisfaction.score=70;
      S.economy.offers.push({id:'test-leader',playerId:l.id,buyer:${acheteur},fee:120000,expires:S.economy.week+1});return {leader:l.id,nom:l.name,proche:t.id,procheNom:t.name,fans:!!S.pressRelations};})()`);
    jeu.call('save');
    const ol = jeu.call('snapshot').sales.offers.find(x => x.id === 'test-leader');
    assert.ok(ol, 'offre pour le leader');
    assert.ok(ol.consequences.includes(`Ce départ touchera le vestiaire : ${prep.procheNom} perdra un peu de moral.`), JSON.stringify(ol.consequences));
    assert.ok(ol.consequences.includes('C’est le leader du vestiaire : le moral du groupe baissera légèrement.'));
    assert.ok(ol.consequences.includes('Le président apprécie : la vente renfloue une caisse passée sous la réserve du club.'));
    if (prep.fans) assert.ok(ol.consequences.includes('C’est un cadre de l’équipe : les supporters le regretteront.'));
    r = jeu.brut('sale_answer', { offerId: 'test-leader', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.deepEqual(r.model.meta.saleAnswer.consequences, ol.consequences);
    const apresL = lire(`({sat:player('${prep.proche}').satisfaction.score,moral:S.morale,trust:S.trust,fans:S.pressRelations?.fanTrust??null})`);
    assert.equal(apresL.sat, 70 + C.satisfactionProches);
    assert.equal(apresL.moral, 70 + C.moralGroupeLeader);
    assert.equal(apresL.trust, 50 + C.confiancePresident);
    if (prep.fans) assert.equal(apresL.fans, 50 + C.supportersCadre);
    // Un joueur sans lien ni statut : aucune conséquence annoncée.
    const banal = lire(`(()=>{const ids=new Set(club().players.slice().sort((a,b)=>roleNote(b)-roleNote(a)).slice(0,6).map(p=>p.id));return club().players.filter(p=>!ids.has(p.id)).sort((a,b)=>roleNote(a)-roleNote(b))[0].id;})()`);
    run(`club().cash=S.clubBudget.clubs[S.club].reserve*2;S.economy.offers.push({id:'test-banal',playerId:'${banal}',buyer:${acheteur},fee:60000,expires:S.economy.week+1})`);
    assert.deepEqual(jeu.call('snapshot').sales.offers.find(x => x.id === 'test-banal').consequences, []);
    run(`S.economy.offers=S.economy.offers.filter(o=>o.id!=='test-banal')`);

    // 10. Garde d'effectif (le moteur complète l'effectif à 40 après chaque commande : on la vérifie sur un effectif
    // réduit à 37 dans le moteur, puis rétabli) : « Accepter » grisé avec la raison, réponse refusée.
    const raisonGarde = 'Tu dois garder au moins 37 joueurs professionnels.';
    const e = jeu.call('snapshot').squad.find(p => !p.sale.blocked && !p.sale.pending && !p.sale.offerId && p.fam !== 0);
    offrir(run, 'test-garde', e.id, acheteur, 100000);
    const garde = lire(`(()=>{const sheet=new Set([...S.lineup,...S.reserves]),c=club(),out=c.players.filter(p=>!sheet.has(p.id)&&p.id!=='${e.id}'&&p.fam!==0).slice(0,c.players.length-37);
      const ids=new Set(out.map(p=>p.id));c.players=c.players.filter(p=>!ids.has(p.id));
      const vue=venteVue().offers.find(o=>o.id==='test-garde').accept;let erreur='';try{venteRepondre({offerId:'test-garde',action:'accept',confirmed:true});}catch(x){erreur=x.message;}
      const n=c.players.length;c.players.push(...out);return {vue,erreur,n};})()`);
    assert.equal(garde.n, 37);
    assert.deepEqual(garde.vue, { available: false, reason: raisonGarde });
    assert.equal(garde.erreur, raisonGarde);
    // Piliers : deux de chaque côté.
    assert.equal(lire(`(()=>{const c={players:[...club().players,{id:'x1',fam:5,pos:'X'},{id:'x2',fam:5,pos:'X'}]};const p=club().players.find(q=>q.fam===0);
      c.players=c.players.filter(q=>q.fam!==0||q.pos!==p.pos||q.id===p.id).concat([{id:'y',fam:0,pos:p.pos}]);return venteGarde(p,c);})()`), 'Tu dois garder au moins deux piliers de chaque côté.');

    // 11. Accords qui tombent à l'exécution, raison écrite (courrier « vente_annulee ») ; le joueur reste au club.
    regler(x => { x.fenetres.periodes = [{ debut: '05-01', fin: '06-30' }]; });
    assert.equal(jeu.call('snapshot').sales.window.open, false);
    r = jeu.brut('sale_answer', { offerId: 'test-garde', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.meta.saleAnswer.deferred, true);
    // a) Garde revérifiée : effectif tombé à 37 entre-temps (exécution appelée directement, effectif rétabli ensuite).
    const tombeGarde = lire(`(()=>{const sheet=new Set([...S.lineup,...S.reserves]),c=club(),out=c.players.filter(p=>!sheet.has(p.id)&&p.id!=='${e.id}'&&p.fam!==0).slice(0,c.players.length-37);
      const ids=new Set(out.map(p=>p.id));c.players=c.players.filter(p=>!ids.has(p.id));S.venteJoueurs.accords[0].date=CDWorldCareer.calendarToday(S);
      venteExecuterAccords();c.players.push(...out);return {ev:S.venteJoueurs.evenements.at(-1),accords:S.venteJoueurs.accords.length,reste:c.players.some(p=>p.id==='${e.id}')};})()`);
    jeu.call('save');
    assert.equal(tombeGarde.ev.type, 'annulee'); assert.equal(tombeGarde.ev.playerId, e.id); assert.equal(tombeGarde.ev.raison, raisonGarde);
    assert.equal(tombeGarde.accords, 0); assert.equal(tombeGarde.reste, true);
    assert.equal(lire(`venteCourriersAccords(S,'annulee',CDWorldCareer.calendarToday(S))`).find(x => x.key === tombeGarde.ev.id).vars.raison, raisonGarde);
    // b) À la clôture de semaine : l'acheteur n'a plus les moyens → l'accord tombe.
    offrir(run, 'test-moyens', e.id, acheteur, 100000);
    r = jeu.brut('sale_answer', { offerId: 'test-moyens', action: 'accept', confirmed: true });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.meta.saleAnswer.deferred, true);
    run(`S.venteJoueurs.accords[0].date=CDWorldCareer.calendarToday(S);S.clubs[${acheteur}].cash=-5e8`);
    m = semaine();
    assert.equal(m.squad.some(p => p.id === e.id), true, 'il reste au club');
    const tombe = lire('S.venteJoueurs.evenements').filter(x => x.type === 'annulee').pop();
    assert.equal(tombe.playerId, e.id); assert.match(tombe.raison, /n’a plus les moyens ou plus de place/);
    assert.ok(!lire('S.ledger').slice(-10).some(l => JSON.stringify(l).includes('Vente : ' + e.name)), 'aucune vente en caisse');
    assert.equal(m.sales.pending.length, 0);

    // 12. Offre spontanée pour un joueur non proposé (meilleurs joueurs, acheteur dans le besoin), au-dessus de la valeur.
    run(`S.economy.offers=[];for(const id of Object.keys(S.economy.listings))delete S.economy.listings[id];`);
    regler(x => { x.spontanees.chanceSemaine = 1; x.spontanees.semaineMin = 0; x.spontanees.maxParSaison = 99; });
    m = semaine();
    const sp = m.sales.offers.filter(o => o.spontaneous);
    assert.equal(sp.length, 1, 'une offre spontanée');
    assert.equal(sp[0].listed, false);
    assert.ok(sp[0].fee >= Math.round(sp[0].value * R.spontanees.fourchette[0] / 10000) * 10000, sp[0].fee + ' / ' + sp[0].value);
    const meilleurs = lire(`club().players.slice().sort((a,b)=>roleNote(b)-roleNote(a)||(a.id<b.id?-1:1)).slice(0,${R.spontanees.candidats + 3}).map(p=>p.id)`);
    assert.ok(meilleurs.includes(sp[0].playerId), 'parmi les meilleurs');
    assert.ok(lire(`venteBesoin(S.clubs[${sp[0].buyerId}],player('${sp[0].playerId}'))`) >= R.spontanees.besoinMin);
    assert.equal(lire('venteCourriers(S)').find(x => x.key === sp[0].id).vars.origine, 'Nous ne l’avions pas proposé : ils sont venus le chercher.');
    // Demander plus fonctionne aussi pour un joueur non proposé.
    run(`S.clubs[${sp[0].buyerId}].cash=5e7`);
    r = jeu.brut('sale_answer', { offerId: sp[0].id, action: 'counter', percent: 5 });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.meta.saleAnswer.fee % 1000, 0);
    restaurer();

    // 13. Expiration : sans réponse, l'offre vaut la semaine en cours et la suivante, puis disparaît.
    const f = m.squad.find(p => !p.sale.blocked && !p.sale.listed && !p.sale.offerId);
    run(`S.economy.offers.push({id:'test-expire',playerId:'${f.id}',buyer:${acheteur},fee:90000,expires:S.economy.week})`);
    assert.ok(jeu.call('snapshot').sales.offers.some(o => o.id === 'test-expire'));
    m = semaine();
    assert.equal(m.sales.offers.some(o => o.id === 'test-expire'), false);

    // 14. Réglage « saison » : vente immédiate toute la saison (hors match).
    regler(x => { x.fenetres.mode = 'saison'; });
    assert.equal(jeu.call('snapshot').sales.window.open, true);
    restaurer();

    // 15. Passage de saison : liste et offres vidées.
    jeu.call('sale_list', { playerId: f.id, listed: true });
    offrir(run, 'test-saison', f.id, acheteur, 90000);
    const fin = lire(`(()=>{settleContracts();return {l:Object.keys(S.economy.listings).length,o:S.economy.offers.length,v:venteVue()};})()`);
    assert.equal(fin.l, 0); assert.equal(fin.o, 0); assert.equal(fin.v.listed.length, 0); assert.equal(fin.v.offers.length, 0);
  } finally { restaurer(); jeu.fermer(); }
});

// Temps de clôture de semaine : 5 joueurs proposés + offre spontanée forcée, comparé à la même clôture sans liste.
// Seuil documenté (GDD §8 critère 6) : au plus +1,5 s, et toujours sous la limite de 15 s du moteur.
const SURCOUT_MAX_MS = 1500;
test('Performance : clôture de semaine (cadence hebdomadaire) avec 5 joueurs proposés et une offre spontanée', { timeout: 600000 }, () => {
  const mesure = liste => {
    const jeu = ouvrir({ hebdomadaire: true, testVm: true });
    try {
      const m = creer(jeu, CLUB), { semaine } = outils(jeu);
      if (liste) {
        for (const p of m.squad.filter(x => !x.sale.blocked).slice(0, 5)) jeu.call('sale_list', { playerId: p.id, listed: true });
        regler(x => { x.spontanees.chanceSemaine = 1; x.spontanees.semaineMin = 0; x.spontanees.maxParSaison = 99; });
      }
      semaine(); // première clôture (préchauffe)
      const t = []; let dernier = null;
      for (let k = 0; k < 2; k++) { const d = Date.now(); dernier = semaine(); t.push(Date.now() - d); }
      return { ms: Math.min(...t), offres: dernier.sales.offers.length, sp: dernier.sales.offers.filter(o => o.spontaneous).length };
    } finally { restaurer(); jeu.fermer(); }
  };
  const sans = mesure(false), avec = mesure(true);
  console.log(`clôture de semaine : sans liste ${sans.ms} ms, avec 5 joueurs proposés ${avec.ms} ms (${avec.offres} offres, ${avec.sp} spontanée)`);
  assert.ok(avec.offres >= 5 && avec.sp >= 1, JSON.stringify(avec));
  assert.ok(avec.ms - sans.ms <= SURCOUT_MAX_MS, `surcoût ${avec.ms - sans.ms} ms > ${SURCOUT_MAX_MS} ms`);
  assert.ok(avec.ms < 15000);
});

// Cadence journalière (celle du jeu) : deux carrières identiques jusqu'à la même semaine, l'une avec 5 joueurs proposés
// et une offre spontanée forcée ; on compare la journée qui clôt cette semaine (même date, même calendrier).
test('Performance et courrier : cadence journalière, clôture de semaine par « advance_day » avec 5 joueurs proposés', { timeout: 900000 }, () => {
  const mesure = liste => {
    const jeu = ouvrir({ testVm: true });
    try {
      let m = creer(jeu, CLUB);
      m = jusquALaSemaineSuivante(jeu, jouerLeMatch(jeu, jusquAuMatch(jeu, m)));
      m = jusquAuMatch(jeu, m);
      if (liste) {
        for (const p of m.squad.filter(x => !x.sale.blocked).slice(0, 5)) m = jeu.call('sale_list', { playerId: p.id, listed: true });
        assert.equal(m.sales.listed.length, 5);
        regler(x => { x.spontanees.chanceSemaine = 1; x.spontanees.semaineMin = 0; x.spontanees.maxParSaison = 99; });
      }
      m = jouerLeMatch(jeu, m);
      const w = m.meta.week; let cloture = null;
      for (let j = 0; j < 12 && m.meta.week === w; j++) {
        m = jeu.regler(m);
        if (m.meta.week !== w) break;
        assert.equal(m.meta.calendarCadence?.canAdvance, true, 'journée autorisée');
        const jour = m.meta.calendarToday, d = Date.now();
        m = jeu.call('advance_day', { fromDate: jour });
        if (m.meta.week !== w) cloture = { jour, ms: Date.now() - d };
      }
      assert.ok(cloture, 'semaine close par advance_day');
      // Courrier « offre_transfert » en Réception (nature info : n'arrête pas « Continuer »).
      for (let j = 0; liste && j < 3 && !m.clubLife?.clubMail?.mails?.some(x => x.type === 'offre_transfert'); j++) {
        m = jeu.regler(m); if (m.meta.calendarCadence?.matchReady && m.next) break;
        m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
      }
      return { ...cloture, offres: m.sales.offers.map(o => o.name), mail: m.clubLife?.clubMail?.mails?.find(x => x.type === 'offre_transfert') ?? null };
    } finally { restaurer(); jeu.fermer(); }
  };
  const sans = mesure(false), avec = mesure(true);
  console.log(`clôture de semaine (advance_day du ${avec.jour}) : sans liste ${sans.ms} ms, avec 5 joueurs proposés ${avec.ms} ms`);
  assert.equal(avec.jour, sans.jour, 'même journée de clôture');
  assert.ok(avec.ms - sans.ms <= SURCOUT_MAX_MS, `surcoût ${avec.ms - sans.ms} ms > ${SURCOUT_MAX_MS} ms`);
  assert.ok(avec.ms < 15000);
  assert.ok(avec.offres.length >= 5, 'offres reçues : ' + avec.offres.length);
  const mail = avec.mail;
  assert.ok(mail, 'courrier reçu');
  assert.equal(mail.nature, 'info'); assert.equal(mail.arret, false); assert.equal(mail.ecran, 'ventes');
  assert.ok(avec.offres.some(nom => mail.sujet.includes(nom)), mail.sujet);
});