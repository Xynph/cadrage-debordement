'use strict';
// Transferts entre clubs v2 (docs/gdd/calendrier-mutations.md § 3 bis, 3 ter, 3 quater ; décision de Léo du 19/11/2026) :
// accords conclus toute l'année et exécutés au changement de saison pour tous les clubs ; tours de marché des clubs gérés
// aux semaines 0 et 13, toutes les quatre semaines de janvier à avril, chaque semaine de la période des mutations (deux
// la dernière) ; pré-contrats et rumeurs entre clubs gérés ; indemnité plafonnée aux salaires repris ; temps forts.
// Mode Monde uniquement (`world-champ`, club 102), cadence hebdomadaire.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/calendrier-mutations.cjs');
const R = require('../native/engine/calendrier-mutations.json');
const RV = require('../native/engine/vente-joueurs.json');
const { ouvrir, creer, jouerLeMatch } = require('./helpers/carriere-monde.cjs');

const CLUB = 102;
const copie = x => JSON.parse(JSON.stringify(x));
const ORIGINE = { cal: copie(R), vente: copie(RV) };
const restaurer = () => {
  for (const k of Object.keys(ORIGINE.cal)) R[k] = copie(ORIGINE.cal[k]);
  for (const k of Object.keys(ORIGINE.vente)) RV[k] = copie(ORIGINE.vente[k]);
};
const decaler = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10);
const md = iso => iso.slice(5, 10);

test('Calendrier des tours, indemnité plafonnée, réglage de mesure', () => {
  const t = (jour, semaine, saison = 2) => { const x = K.toursClubs(jour, semaine, saison); return [x.tours, x.motif]; };
  assert.deepEqual(t('2027-08-30', 0), [1, 'semaine'], 'semaine 0');
  assert.deepEqual(t('2026-08-31', 0, 1), [0, null], 'pas la semaine 0 de la première saison');
  assert.deepEqual(t('2026-11-30', 13), [1, 'semaine'], 'semaine 13');
  assert.deepEqual(t('2026-10-12', 6), [0, null], 'automne : aucun tour');
  assert.deepEqual(t('2027-01-04', 18), [1, 'hiver'], 'hiver : première semaine');
  assert.deepEqual(t('2027-01-11', 19), [0, null]);
  assert.deepEqual(t('2027-01-29', 22), [1, 'hiver'], 'quatre semaines plus tard');
  assert.deepEqual(t('2027-05-03', 35), [1, 'mutations']);
  assert.deepEqual(t('2027-06-21', 42), [1, 'mutations']);
  assert.deepEqual(t('2027-06-28', 43), [2, 'derniere'], 'dernière semaine : deux tours');
  assert.deepEqual(t('2027-07-05', 44), [0, null]);
  // Indemnité ≤ salaire × 52 × saisons restantes après l'arrivée ; plancher 10 000 €.
  assert.equal(K.plafondIndemnite(5000, 3, 2), 260000);
  assert.equal(K.indemnite(1e6, 5000, 3, 2), 260000);
  assert.equal(K.indemnite(120000, 5000, 4, 2), 120000, 'sous le plafond : inchangée');
  assert.equal(K.indemnite(1e6, 5000, 2, 2), 10000, 'fin de contrat : plancher');
  assert.equal(K.calendrierClubs(), 'mutations');
  process.env.CD_CLUBS_GERES_CALENDRIER = 'semaines';
  try { assert.equal(K.calendrierClubs(), 'semaines'); } finally { delete process.env.CD_CLUBS_GERES_CALENDRIER; }
  // Hors période : accord toujours possible, arrivée à la bascule.
  assert.equal(K.interclub('2026-10-12', RV, '2027-07-01').raison, 'Hors période des mutations : un accord conclu maintenant prendra effet le 1er juillet 2027 ; les autres clubs n’enchérissent qu’à partir du 1er mai 2027.');
});

test('Monde : accord entre clubs gérés payé à l’accord, président à la conclusion, acheteur au-dessus de sa capacité à la bascule', { timeout: 300000 }, () => {
  // Décisions de Léo du 20/11/2026 (GDD calendrier-mutations § 3 bis 1 et 5) : l'indemnité passe d'une caisse à l'autre dès
  // l'accord ; le président d'un acheteur passé sous sa réserve tranche à la conclusion, ses ventes sont des accords payés
  // tout de suite (joueur au 1er juillet) ; à la bascule l'accord ne tombe plus faute de place : l'acheteur libère des joueurs.
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    // Accord entre deux clubs gérés de l'élite ; l'acheteur, après l'indemnité, tombe à 30 % de sa réserve (« Fragile »).
    const x = lire(`(()=>{const geres=S.clubs.filter(c=>c.id!==S.club&&budgetLigue(c.id)==='elite');
      const b=geres[0],s=geres[1];
      const p=s.players.filter(q=>q.contractEnd>S.season).sort((u,v)=>u.rating-v.rating||(u.id<v.id?-1:1))[0];
      const reserve=S.clubBudget.clubs[b.id].reserve,montant=Math.max(500000,Math.round(reserve*0.2/10000)*10000);
      b.cash=montant+Math.round(reserve*0.3);const cb=b.cash,cs=s.cash;
      calIANouvelAccord(b,s,p,montant,p.salary,2);
      return {b:b.id,s:s.id,p:p.id,montant,cb,cs,apresB:b.cash,apresS:s.cash,ici:s.players.some(q=>q.id===p.id),plan:S.presidentReprise?.clubs?.[b.id]||null};})()`);
    assert.equal(x.apresB, x.cb - x.montant, 'l’acheteur paie à l’accord');
    assert.equal(x.apresS, x.cs + x.montant, 'le vendeur encaisse à l’accord');
    assert.equal(x.ici, true, 'le joueur reste à son club jusqu’à la bascule');
    assert.ok(x.plan && x.plan.etat === 'en_cours', 'le président intervient à la conclusion');
    // Page « Dans le monde » (idée FM27 n° 30) : le transfert entre clubs adverses est gardé et projeté (carte « Dernière minute »).
    const garde = lire('S.mondeTransferts[0]');
    assert.deepEqual([garde.type, garde.playerId, garde.vendeurId, garde.acheteurId, garde.montant], ['accord', x.p, x.s, x.b, x.montant], 'transfert du monde gardé');
    const vu = jeu.call('snapshot').monde.transferts[0];
    assert.equal(vu.playerId, x.p, 'transfert du monde projeté pour la page « Dans le monde »');
    // Échéance du président : ses ventes deviennent des accords payés tout de suite, joueurs au 1er juillet.
    const v = lire(`(()=>{const b=S.clubs[${x.b}],plan=S.presidentReprise.clubs[${x.b}];plan.echeance=CDWorldCareer.calendarToday(S);const avant=b.cash;repriseSemaine();
      const ventes=S.calendrierMutations.accordsIA.filter(a=>a.vendeurId===${x.b}&&a.saison===S.season);
      return {etat:plan.etat,avant,apres:b.cash,ventes:ventes.map(a=>({playerId:a.playerId,montant:a.montant,paye:!!a.paye,ici:b.players.some(q=>q.id===a.playerId)}))};})()`);
    assert.equal(v.etat, 'vendu');
    assert.ok(v.ventes.length >= 1 && v.ventes.every(a => a.paye && a.ici), JSON.stringify(v.ventes));
    assert.equal(v.apres, v.avant + v.ventes.reduce((t, a) => t + a.montant, 0), 'argent des ventes encaissé tout de suite');
    // L'acheteur dépasse sa capacité à la bascule (joueurs ajoutés sous contrat) : l'accord est honoré, il libère des joueurs.
    const r = lire(`(()=>{const b=S.clubs[${x.b}],cap=professionalCapacity(b),autres=S.clubs.filter(c=>c.id!==S.club&&c.id!==${x.b}&&c.id!==${x.s});
      for(const c of autres){if(b.players.length>=cap+3)break;const q=c.players.find(q=>q.contractEnd>S.season+1);if(!q)continue;c.players=c.players.filter(y=>y!==q);q.joinedSeason=S.season-1;b.players.push(q);}
      for(const q of b.players)if(q.contractEnd!=null&&q.contractEnd<=S.season)q.contractEnd=S.season+1;
      const cash=b.cash;settleContracts();
      return {arrive:b.players.some(q=>q.id==='${x.p}'),n:b.players.length,cap,cash,cashApres:b.cash,fil:S.economy.transfers.map(t=>t.text)};})()`);
    assert.equal(r.arrive, true, 'accord honoré malgré l’effectif plein');
    assert.ok(r.n <= r.cap, 'revenu à sa capacité : ' + r.n + '/' + r.cap);
    assert.ok(r.fil.some(t => t.includes(' pour revenir à ' + r.cap + ' joueurs après ses arrivées.')), 'libérations écrites');
    assert.ok(lire('S.mondeTransferts').some(t => t.playerId === x.p), 'transfert du monde toujours gardé après la bascule');
  } finally { jeu.fermer(); }
});
test('Monde : tours des clubs gérés, accords différés, pré-contrats, rumeurs, temps forts, bascule', { timeout: 900000 }, () => {
  const debut = Date.now();
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    const run = s => { const r = jeu.bridge.vm.run(s); jeu.call('save'); return r; };
    const jour = () => lire('CDWorldCareer.calendarToday(S)');
    const semaine = () => { const m = jeu.regler(jeu.call('snapshot')); return m.next ? jouerLeMatch(jeu, m) : jeu.regler(jeu.call('finish_round')); };
    const etat = () => lire('S.calendrierMutations||{}');
    // Espion : tours de marché demandés à chaque clôture (semaine, tours, différés).
    jeu.bridge.vm.run(`globalThis.__tours=[];{const v1=nativeClubDirections.openWindow;nativeClubDirections.openWindow=function(r,d){__tours.push([S.round,r,d]);return v1.apply(this,arguments);};}`);
    assert.equal(lire('nativeClubDirections.active()'), true, 'directions des clubs actives');

    // 1. Septembre : aucun tour (ni semaine fixe, ni hiver, ni période des mutations). Puis une semaine fixe (réglage
    //    semainesFixes, la semaine 13 réelle étant à trois mois) : un tour, en accords ; personne ne change de club.
    const proprietaires = () => lire(`Object.fromEntries(S.clubs.filter(c=>c.id!==S.club).flatMap(c=>c.players.map(p=>[p.id,c.id])))`);
    for (let k = 0; k < 3; k++) semaine();
    assert.deepEqual(lire('__tours'), [], 'aucun tour en septembre');
    const fixe = lire('S.round') + 1;
    R.clubsGeres.semainesFixes = [0, fixe];
    semaine();
    restaurer();
    const tours = lire('__tours');
    assert.deepEqual(tours, [[fixe, 1, true]], 'un tour en accords la semaine fixe : ' + JSON.stringify(tours));
    let st = etat();
    assert.ok(st.accordsIA.length > 0, 'accords conclus à la semaine 13');
    const avant = proprietaires();
    for (const a of st.accordsIA) {
      assert.equal(avant[a.playerId], a.vendeurId, 'le joueur reste à son club jusqu’à la bascule');
      assert.ok(a.montant >= 10000 && a.montant <= Math.max(10000, lire(`S.clubs[${a.vendeurId}].players.find(p=>p.id==='${a.playerId}')`).salary * 52 * (lire(`S.clubs[${a.vendeurId}].players.find(p=>p.id==='${a.playerId}').contractEnd`) - lire('S.season'))), 'indemnité plafonnée');
    }
    assert.ok(lire(`S.economy.transfers.some(t=>/s’est mis d’accord avec .+ : il arrivera le 1er juillet/.test(t.text))`), 'fil des transferts');
    assert.equal(lire(`S.manager.inbox.filter(m=>/s’est mis d’accord/.test(m.title)).length`), 0, 'pas de courrier pour les accords des clubs gérés');
    const parAcheteur = new Map();
    for (const a of st.accordsIA) parAcheteur.set(a.acheteurId, (parAcheteur.get(a.acheteurId) || 0) + 1);
    assert.ok([...parAcheteur.values()].every(n => n === 1), 'un tour : un accord par acheteur');

    // 2. Joueur engagé : refusé au club joué avec la raison ; joueur en fin de contrat : pré-contrat seulement.
    const marche = () => lire(`nativeSystems.domain('interclubMarket').project()`);
    let liste = marche();
    const engage = st.accordsIA[0];
    const c1 = liste.candidates.find(c => c.id === engage.playerId);
    assert.equal(c1.available, false);
    assert.equal(c1.reason, 'Transfert conclu avec ' + engage.acheteur + ' : il le rejoindra le 1er juillet 2027');
    const fin = liste.candidates.find(c => c.contractEnd === lire('S.season'));
    assert.equal(fin.reason, 'Son contrat s’achève cette saison : propose-lui un pré-contrat à partir du 1er janvier');
    // Indemnité du club joué plafonnée aux salaires repris.
    for (const c of liste.candidates.filter(c => c.contractEnd > lire('S.season')).slice(0, 200)) assert.ok(c.fee <= Math.max(10000, c.sourceSalary * 52 * (c.contractEnd - lire('S.season'))), c.id);

    // 3. Achat du club joué : accord conclu tout de suite, arrivée au changement de saison.
    run('club().cash=Math.max(club().cash,9e6);(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
    liste = marche();
    const cible = liste.candidates.filter(c => c.available).sort((a, b) => a.fee - b.fee || (a.id < b.id ? -1 : 1))[0];
    let r = jeu.brut('interclub_transfer', { playerId: cible.id, sellerId: cible.clubId, fee: cible.fee, salary: cible.salary, sourceSalary: cible.sourceSalary, contractEnd: cible.contractEnd, context: liste.context, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.interclubTransfer.deferred, true); assert.equal(r.model.meta.interclubTransfer.date, '2027-07-01');
    assert.equal(lire(`S.clubs[${cible.clubId}].players.some(p=>p.id==='${cible.id}')`), true, 'il reste à son club');

    // 4. Pré-contrats entre clubs gérés et rumeurs (fenêtre élargie pour l'automne : moins de 12 mois de contrat).
    R.preContrats.moisAvantFin = 12; R.clubsGeres.rumeurs.fin = '12-31';
    semaine();
    st = etat();
    assert.ok(st.ia.length >= 1 && st.ia.length <= R.clubsGeres.preContrats.parSemaine, 'pré-contrats de la semaine : ' + st.ia.length);
    assert.ok(st.rumeurs.length >= 1, 'rumeur');
    const pre = st.ia[0];
    assert.equal(lire(`S.clubs[${pre.vendeurId}].players.find(p=>p.id==='${pre.playerId}').contractEnd`), lire('S.season'));
    assert.ok(lire('S.news').some(t => t === pre.acheteur + ' a signé ' + pre.nom + ' (' + pre.pos.toLowerCase() + ' de ' + pre.vendeur + ') pour la saison prochaine.'), 'actualité du pré-contrat');
    assert.ok(lire('S.news').some(t => /^Selon la presse, .+ suit .+ en fin de contrat\.$/.test(t)), 'actualité de rumeur');
    const lignes = st.mercato.semaines[String(lire('S.round'))];
    assert.ok(lignes.some(l => l.type === 'precontrat') && lignes.some(l => l.type === 'rumeur'), 'résumé de la semaine');
    const candPre = marche().candidates.find(c => c.id === pre.playerId);
    assert.equal(candPre.reason, 'A signé un pré-contrat avec ' + pre.acheteur + ' pour la saison prochaine');
    assert.equal(candPre.preContract.available, false);
    assert.equal(candPre.preContract.reason, 'A signé un pré-contrat avec ' + pre.acheteur + ' pour la saison prochaine.');
    // Rejeu : même graine, même semaine → mêmes signatures et rumeurs.
    const rejeu = lire(`(()=>{const avant=JSON.stringify(S.calendrierMutations),cle=S.season+':'+S.round,st=S.calendrierMutations;
      const sig=()=>JSON.stringify([st.ia.filter(x=>x.date===CDWorldCareer.calendarToday(S)).map(x=>[x.playerId,x.acheteurId,x.salaire,x.annees]),st.rumeurs.filter(x=>x.date===CDWorldCareer.calendarToday(S)).map(x=>[x.playerId,x.interesseId])]);
      const a=sig();st.ia=st.ia.filter(x=>x.date!==CDWorldCareer.calendarToday(S));st.rumeurs=st.rumeurs.filter(x=>x.date!==CDWorldCareer.calendarToday(S));st.iaSemaine=null;
      const n0=S.news.length;calIAPreContrats();const b=sig();S.calendrierMutations=JSON.parse(avant);return {a,b};})()`);
    assert.equal(rejeu.b, rejeu.a, 'tirage déterministe');
    restaurer();

    // 5. Période des mutations simulée : prochaine clôture dans la période, la suivante est la dernière semaine.
    const j0 = jour();
    RV.fenetres.periodes = [{ debut: md(decaler(j0, 1)), fin: md(decaler(j0, 20)) }];
    const n0 = lire('__tours.length');
    semaine();
    assert.deepEqual(lire('__tours').slice(n0).map(x => x.slice(1)), [[1, true]], 'un tour en période');
    assert.ok(lire('S.news').some(t => t.startsWith('Ouverture de la période des mutations : ')), 'temps fort d’ouverture');
    semaine();
    assert.deepEqual(lire('__tours').slice(n0 + 1).map(x => x.slice(1)), [[2, true]], 'deux tours la dernière semaine');
    st = etat();
    assert.ok(st.mercato.ouverture && st.mercato.derniere, 'ouverture et dernière semaine notées');
    assert.ok(lire('S.news').some(t => t.startsWith('Dernière semaine du mercato : ')));
    semaine();
    st = etat();
    assert.ok(st.mercato.bilan, 'bilan après la période');
    assert.ok(lire('S.news').some(t => t.startsWith('Bilan du mercato : ')));
    restaurer();

    // 6. Changement de saison : accords et pré-contrats exécutés avant les prolongations des clubs gérés.
    st = etat();
    const accords = st.accordsIA.filter(a => a.saison === lire('S.season')), pres = st.ia.filter(x => x.etat === 'signe');
    const caisses = lire('S.clubs.map(c=>c.cash)');
    const b = lire(`(()=>{settleContracts();return {own:club().players.some(p=>p.id==='${cible.id}'),
      ou:Object.fromEntries(S.clubs.flatMap(c=>c.players.map(p=>[p.id,c.id]))),joueurs:Object.fromEntries(S.clubs.flatMap(c=>c.players.map(p=>[p.id,{contractEnd:p.contractEnd,salary:p.salary}]))),
      st:S.calendrierMutations,news:S.news};})()`);
    assert.equal(b.own, true, 'l’achat du club joué arrive au changement de saison');
    const faits = accords.filter(a => b.ou[a.playerId] === a.acheteurId);
    assert.ok(faits.length >= Math.ceil(accords.length / 2), 'accords exécutés : ' + faits.length + '/' + accords.length);
    for (const a of faits) { assert.equal(b.joueurs[a.playerId].contractEnd, lire('S.season') + a.annees); assert.equal(b.joueurs[a.playerId].salary, a.salaire); }
    const prefaits = pres.filter(x => b.ou[x.playerId] === x.acheteurId);
    assert.ok(prefaits.length >= 1, 'pré-contrats exécutés');
    for (const x of prefaits) assert.ok(b.joueurs[x.playerId].contractEnd > lire('S.season'), 'nouveau contrat, pas de prolongation chez l’ancien club');
    assert.equal(b.st.accordsIA.length, 0, 'accords purgés');
    assert.ok(b.news.some(t => /^\d+ transferts entre clubs prennent effet en ce changement de saison\.$/.test(t)), 'actualité de la bascule');
    assert.ok(caisses.length === lire('S.clubs.length'));
    console.log(`clubs-geres-mutations : ${accords.length} accords, ${pres.length} pré-contrats, ${((Date.now() - debut) / 1000).toFixed(0)} s`);
  } finally { restaurer(); jeu.fermer(); }
});

test('Monde : rumeurs fausses démenties (taux 0), rumeurs vraies suivies d’un pré-contrat (taux 1)', { timeout: 900000 }, () => {
  const debut = Date.now();
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, CLUB);
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    const jour = () => lire('CDWorldCareer.calendarToday(S)');
    const semaine = () => { const m = jeu.regler(jeu.call('snapshot')); return m.next ? jouerLeMatch(jeu, m) : jeu.regler(jeu.call('finish_round')); };
    const etat = () => lire('S.calendrierMutations||{}');
    // Pré-contrats et rumeurs dès l'automne (moins de 12 mois de contrat, rumeurs jusqu'au 31 décembre).
    R.preContrats.moisAvantFin = 12; R.clubsGeres.rumeurs.fin = '12-31';

    // 1. Taux 0 : toutes les rumeurs sont fausses ; jamais de pré-contrat avec le club annoncé ; démenti 2 à 4 semaines après.
    R.clubsGeres.rumeurs.tauxRealisation = 0;
    semaine();
    let st = etat();
    const fausses = st.rumeurs.slice();
    assert.ok(fausses.length >= 1, 'rumeurs de la semaine');
    for (const r of fausses) {
      assert.equal(r.piste, 'fausse', r.id);
      assert.ok(r.dementi >= decaler(r.date, 14) && r.dementi <= decaler(r.date, 28), 'démenti dans le délai : ' + r.date + ' → ' + r.dementi);
    }
    R.clubsGeres.rumeurs.parSemaine = 0; R.clubsGeres.rumeurs.actives = false; // plus de nouvelle rumeur : on suit celles-ci
    const dementis = new Map();
    for (let k = 0; k < 5; k++) {
      semaine();
      st = etat();
      const j = jour();
      for (const r of st.rumeurs) if (r.suite === 'dementi' && !dementis.has(r.id)) {
        assert.ok(j >= r.dementi && j < decaler(r.dementi, 7), 'démenti à la première clôture après ' + r.dementi + ' : ' + j);
        dementis.set(r.id, j);
      }
      for (const r of fausses) assert.ok(!st.ia.some(x => x.playerId === r.playerId && x.acheteurId === r.interesseId && x.saison === r.saison), 'pas de pré-contrat avec le club annoncé : ' + r.nom);
    }
    for (const r of st.rumeurs.filter(r => fausses.some(f => f.id === r.id))) assert.ok(r.suite === 'dementi' || r.suite === 'sans-suite', r.id + ' : ' + r.suite);
    assert.ok(dementis.size >= 1, 'au moins un démenti');
    const d0 = st.rumeurs.find(r => r.suite === 'dementi');
    const texte = d0.interesse + ' dément tout intérêt pour ' + d0.nom + ' (' + d0.pos.toLowerCase() + ' de ' + d0.club + ').';
    assert.ok(lire('S.news').includes(texte), 'actualité du démenti : ' + texte);
    assert.ok(Object.values(st.mercato.semaines).flat().some(l => l.type === 'rumeur' && l.texte === texte), 'ligne du mercato');
    restaurer();

    // 2. Taux 1 : comportement d'avant, la rumeur est prioritaire et suivie d'un pré-contrat avec le club annoncé.
    R.preContrats.moisAvantFin = 12; R.clubsGeres.rumeurs.fin = '12-31'; R.clubsGeres.rumeurs.tauxRealisation = 1;
    const n0 = etat().rumeurs.length;
    semaine();
    const vraies = etat().rumeurs.slice(n0);
    assert.ok(vraies.length >= 1 && vraies.every(r => r.piste === 'vraie' && !r.dementi), 'rumeurs vraies');
    R.clubsGeres.rumeurs.parSemaine = 0; R.clubsGeres.rumeurs.actives = false;
    for (let k = 0; k < 2; k++) semaine();
    st = etat();
    const suivies = st.rumeurs.filter(r => vraies.some(v => v.id === r.id) && r.suite === 'signe');
    assert.ok(suivies.length >= 1, 'rumeur suivie d’un pré-contrat');
    // Comme avant : le club annoncé passe en tête ; s'il ne peut plus acheter, un autre signe et la rumeur compte comme suivie.
    for (const r of suivies) assert.ok(st.ia.some(x => x.playerId === r.playerId && x.saison === r.saison), 'pré-contrat signé : ' + r.nom);
    assert.ok(!st.rumeurs.some(r => r.suite === 'dementi' && vraies.some(v => v.id === r.id)), 'aucun démenti d’une vraie piste');
    console.log(`clubs-geres-mutations (rumeurs) : ${fausses.length} fausses, ${dementis.size} démenties, ${vraies.length} vraies, ${suivies.length} suivies, ${((Date.now() - debut) / 1000).toFixed(0)} s`);
  } finally { restaurer(); jeu.fermer(); }
});
