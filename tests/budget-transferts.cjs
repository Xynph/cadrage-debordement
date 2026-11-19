'use strict';
// Budget de transferts (native/engine/budget-transferts.cjs, docs/gdd/budget-transferts.md) : enveloppe fixée par le
// conseil, refus avant signature, débit des primes et indemnités, matelas de la caisse, exemption de la reprise du
// président, recettes (formation +50 %, ventes imposées 0), passage de saison, carrière antérieure, réglages JSON,
// rallonge demandée au conseil (R3 bis) et report partiel d'une saison à l'autre (R5).
// Mode Monde uniquement (`world-champ`, Castres Tarn Rugby, club 9, Top 14).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const T = require('../native/engine/budget-transferts.cjs');
const R = require('../native/engine/budget-transferts.json');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const CLUB = 9;
const outils = jeu => {
  // Retouche de la carrière suivie d'une sauvegarde : une consultation (négociation) refuse une carrière modifiée hors commande.
  const run = s => { const r = jeu.bridge.vm.run(s); jeu.call('save'); return r; }, lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
  const vue = () => jeu.call('snapshot').finance.transferBudget;
  const fixer = (depense, reconstitue = 0) => run(`(()=>{const e=budgetTransfertsEtat(true);e.depense=${depense};e.reconstitue=${reconstitue};})()`);
  return { run, lire, vue, fixer };
};
// Devis de l'écran Marché entre clubs (domaine interclubMarket), comme Godot les lit.
const devis = lire => lire(`nativeSystems.domain('interclubMarket').project()`);
const offre = (q, context) => ({ playerId: q.id, sellerId: q.clubId, fee: q.fee, salary: q.salary, sourceSalary: q.sourceSalary, contractEnd: q.contractEnd, context });

const P = T.REGLAGES, Q = P.rallonge;
const arrondi = (x, pas) => Math.round(x / pas) * pas;
const facteurConfiance = c => P.confiance.min + (P.confiance.max - P.confiance.min) * c / 100;

test('Formule : exemple du GDD (Castres), plancher, plafond, matelas, refus et part des ventes', () => {
  const castres = { recettes: 29.6e6, division: 'elite', type: 'entreprise', confiance: 72, cash: 3.7e6, reserve: 3.78e6 };
  const brut = 29.6e6 * P.taux.elite * P.ambition.entreprise * facteurConfiance(72) * Math.min(P.tresorerie.max, Math.max(P.tresorerie.min, 3.7e6 / 3.78e6));
  assert.equal(T.enveloppe(castres), arrondi(Math.min(Math.max(brut, 29.6e6 * P.plancher), 29.6e6 * P.plafond), P.arrondi), 'GDD : exemple Castres');
  const mat = T.matelas(3.78e6);
  assert.equal(mat, Math.round(Math.max(P.matelas.fixe, P.matelas.partReserve * 3.78e6)));
  assert.equal(T.matelas(null), P.matelas.fixe, 'réserve illisible : matelas fixe');
  assert.equal(T.matelas(0.5e6), Math.round(Math.max(P.matelas.fixe, P.matelas.partReserve * 0.5e6)));
  // Confiance 0 : facteur minimal, jamais zéro ; caisse vide : plancher des recettes.
  const minimum = 29.6e6 * P.taux.elite * P.confiance.min * P.tresorerie.min;
  assert.equal(T.enveloppe({ ...castres, confiance: 0, cash: 0 }), arrondi(Math.min(Math.max(minimum, 29.6e6 * P.plancher), 29.6e6 * P.plafond), P.arrondi), 'facteurs au minimum');
  assert.equal(T.enveloppe({ ...castres, division: 'accession', type: 'association', confiance: 0, cash: 0 }),
    arrondi(Math.max(29.6e6 * P.taux.accession * P.ambition.association * P.confiance.min * P.tresorerie.min, 29.6e6 * P.plancher), P.arrondi), 'plancher');
  assert.ok(T.enveloppe({ ...castres, type: 'mecene', confiance: 100, cash: 99e6 }) <= 29.6e6 * P.plafond + P.arrondi / 2, 'plafond');
  // Pro D2 / autres championnats : taux propre ou défaut.
  assert.ok(T.enveloppe({ ...castres, division: 'accession' }) <= T.enveloppe(castres));
  assert.equal(T.enveloppe({ ...castres, division: 'prem' }), T.enveloppe({ ...castres, division: 'defaut' }), 'taux par défaut');
  const e = { enveloppe: 1160000, depense: 920000, reconstitue: 0 };
  assert.equal(T.refus(e, 240000, 9e6, 1.89e6), null, 'pile le reste');
  assert.equal(T.refus(e, 240001, 9e6, 1.89e6), `Hors budget de transferts : il reste ${T.euros(240000)} sur l’enveloppe de ${T.euros(1160000)} fixée par le conseil.`);
  assert.equal(T.refus(e, 100000, 1.9e6, 1.89e6), `La caisse ne permet plus de transfert : elle doit rester au-dessus de ${T.euros(1.89e6)}.`);
  assert.equal(T.disponible(e, 1e6, 1.89e6), 0, 'caisse sous le matelas : 0, jamais négatif');
  assert.equal(T.rendu({ enveloppe: 640000, reconstitue: 0 }, 300000, 29.6e6), Math.round(P.partVentes * 300000), 'part d’une vente choisie');
  assert.equal(T.rendu({ enveloppe: 29.6e6 * P.plafond - 100000, reconstitue: 0 }, 1e6, 29.6e6), 100000, 'plafonné au plafond des recettes');
});

test('Rallonge (R3 bis) et report (R5) : montant demandé, décision du président, caisse limitante, report plafonné', () => {
  const e = { enveloppe: 1000000, depense: 900000, reconstitue: 0 };
  // Montant manquant arrondi au millier supérieur ; rien si l'offre passe ; rien si la caisse limite.
  assert.equal(T.demandeRallonge(e, 100000, 9e6, 1.89e6), 0, 'pile le reste');
  const pas = Q.arrondi, hautPas = x => Math.ceil(x / pas) * pas, basPas = x => Math.floor(x / pas) * pas;
  assert.equal(T.demandeRallonge(e, 100001, 9e6, 1.89e6), hautPas(1));
  assert.equal(T.demandeRallonge(e, 245500, 9e6, 1.89e6), hautPas(145500));
  assert.equal(T.demandeRallonge(e, 300000, 1.89e6 + 250000, 1.89e6), 0, 'caisse − matelas < offre : pas de rallonge');
  assert.equal(T.refus(e, 300000, 1.89e6 + 250000, 1.89e6), `Hors budget de transferts : il reste ${T.euros(100000)} sur l’enveloppe de ${T.euros(1e6)} fixée par le conseil. Une rallonge du conseil ne suffirait pas : la caisse doit rester au-dessus de ${T.euros(1.89e6)}.`);
  assert.equal(T.refus(e, 200000, 9e6, 1.89e6), `Hors budget de transferts : il reste ${T.euros(100000)} sur l’enveloppe de ${T.euros(1e6)} fixée par le conseil.`);
  // Enveloppe de la saison = fixée + report + rallonge.
  const f = { ...e, report: 50000, rallonge: 20000 };
  assert.equal(T.total(f), 1070000); assert.equal(T.reste(f), 170000);
  assert.match(T.refus(f, 200000, 9e6, 1.89e6), /il reste 170 000 € sur l’enveloppe de 1 070 000 €/);
  // Décision : nombre de rallonges, puis confiance, puis part de l'enveloppe fixée.
  const part = Math.round(Q.partEnveloppe * 100), maxPart = Math.floor(Q.partEnveloppe * e.enveloppe), pluriel = Q.maxParSaison > 1 ? 's' : '';
  assert.equal(T.decisionRallonge(e, maxPart, Q.confianceMin), null, 'seuil et part pile : accordée');
  assert.equal(T.decisionRallonge(e, 1000, Q.confianceMin - 1), `Le président refuse : sa confiance (${Q.confianceMin - 1}/100) est trop basse pour rouvrir l’enveloppe ; il en faut ${Q.confianceMin}.`);
  assert.equal(T.decisionRallonge(e, maxPart + 1000, 100), `Le président refuse : ${T.euros(maxPart + 1000)} dépassent ${part} % de l’enveloppe fixée en début de saison (${T.euros(maxPart)} au plus).`);
  assert.equal(T.decisionRallonge({ ...e, rallongesAccordees: Q.maxParSaison }, 1000, 100), `Le président refuse : le conseil a déjà accordé ${Q.maxParSaison} rallonge${pluriel} cette saison.`);
  assert.equal(T.decisionRallonge({ ...e, rallongesAccordees: Q.maxParSaison - 1 }, 1000, 100), null);
  // Report : part du reste non dépensé (enveloppe + report + rallonge + reconstitué − dépensé), millier inférieur, plafonné.
  const fin = { enveloppe: 640000, report: 40000, rallonge: 30000, reconstitue: 10000, depense: 300000 };
  assert.equal(T.report(fin, 700000, 29.6e6), basPas(P.partReport * 420000));
  assert.equal(T.report(fin, 29.6e6 * P.plafond - 20000, 29.6e6), Math.min(basPas(P.partReport * 420000), 20000), 'plafond : enveloppe neuve + report ≤ plafond des recettes');
  assert.equal(T.report({ ...fin, depense: 2e6 }, 700000, 29.6e6), 0, 'rien à reporter');
  // Le reconstitué reste plafonné en comptant le report.
  assert.equal(T.rendu({ enveloppe: 29.6e6 * P.plafond - 150000, report: 50000, reconstitue: 0 }, 1e6, 29.6e6), Math.min(Math.round(P.partVentes * 1e6), 100000));
  assert.equal(T.valide({ version: 1, saison: 1, clubId: 9, enveloppe: 1, depense: 0, reconstitue: 0 }), true, 'sauvegarde antérieure valide');
  assert.equal(T.valide({ version: 1, saison: 1, clubId: 9, enveloppe: 1, depense: 0, reconstitue: 0, rallonge: -1 }), false);
});

test('Critère 9 : changer les valeurs du JSON change l’enveloppe sans modifier le code', () => {
  const x = { recettes: 29.6e6, division: 'elite', type: 'entreprise', confiance: 72, cash: 3.7e6, reserve: 3.78e6 };
  const avant = T.enveloppe(x), taux = R.taux.elite, ambition = R.ambition.entreprise;
  try {
    R.taux.elite = taux * 1.5;
    assert.equal(T.enveloppe(x), Math.round(avant * 1.5 / 10000) * 10000);
    R.taux.elite = taux; R.ambition.entreprise = ambition * 0.5;
    assert.equal(T.enveloppe(x), Math.round(avant * 0.5 / 10000) * 10000);
  } finally { R.taux.elite = taux; R.ambition.entreprise = ambition; }
  assert.equal(T.enveloppe(x), avant);
});

test('Moteur Monde : enveloppe, refus, débits, matelas, président, recettes, saison, carrière antérieure', { timeout: 300000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let m = creer(jeu, CLUB);
    const { run, lire, vue, fixer } = outils(jeu);
    assert.equal(lire('budgetLigue(S.club)'), 'elite');
    const x = lire('budgetTransfertsEntrees()');

    // 1. Enveloppe fixée à la création, lue dans finance.transferBudget, entre 0,5 % et 6 % des recettes.
    let v = m.finance.transferBudget;
    assert.deepEqual(Object.keys(v).sort(), ['actif', 'caisseLibre', 'demandes', 'depense', 'disponible', 'enveloppe', 'matelas', 'rallonge', 'rallongeArrondi', 'rallongeCout', 'rallongeMax', 'rallongesAccordees', 'reconstitue', 'report', 'reste', 'saison']);
    assert.equal(v.report, 0, 'pas de report à la création'); assert.equal(v.rallonge, 0);
    assert.equal(v.reste, v.enveloppe); assert.equal(v.disponible, Math.min(v.reste, v.caisseLibre));
    assert.equal(v.actif, true);
    assert.equal(v.enveloppe, T.enveloppe(x));
    assert.deepEqual(lire('S.budgetTransferts'), { version: 1, saison: v.saison, clubId: CLUB, enveloppe: v.enveloppe, depense: 0, reconstitue: 0, report: 0, rallonge: 0, demandes: 0, rallongesAccordees: 0 }, 'fixée à la création');
    assert.ok(v.disponible >= x.recettes * P.plancher && v.disponible <= x.recettes * P.plafond, 'disponible ' + v.disponible);
    assert.equal(v.matelas, T.matelas(x.reserve));
    assert.ok([v.enveloppe, v.depense, v.reconstitue, v.disponible, v.matelas].every(Number.isInteger), 'euros entiers');

    // 2. Joueur libre hors budget : devis grisé avec la raison, commande refusée, caisse et effectif inchangés.
    const libre = m.market.find(p => p.available && p.maxYears >= 2 && p.fee > 0);
    assert.ok(libre, 'un joueur libre recrutable');
    fixer(v.enveloppe - (libre.fee - 1));
    const raison = `Hors budget de transferts : il reste ${T.euros(libre.fee - 1)} sur l’enveloppe de ${T.euros(v.enveloppe)} fixée par le conseil.`;
    m = jeu.call('snapshot');
    const grise = m.market.find(p => p.id === libre.id);
    assert.equal(grise.available, false); assert.equal(grise.reason, raison);
    const avant = lire('({cash:club().cash,n:club().players.length})');
    const salaire = Math.min(100000, Math.ceil(libre.salary * 1.4 / 100) * 100);
    let r = jeu.brut('recruit', { playerId: libre.id, salary: salaire, years: 2, confirmed: true });
    assert.equal(r.ok, false); assert.equal(r.error, raison);
    assert.deepEqual(lire('({cash:club().cash,n:club().players.length})'), avant);

    // 3. Recrue dans l'enveloppe : le disponible baisse exactement de la prime.
    fixer(0);
    const d0 = vue().disponible;
    r = jeu.brut('recruit', { playerId: libre.id, salary: salaire, years: 2, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.negotiation?.status ?? lire(`S.economy.talks[talkKey('${libre.id}','recruit')].status`), 'signed');
    assert.equal(lire('S.budgetTransferts.depense'), libre.fee);
    assert.equal(vue().disponible, d0 - libre.fee);
    // Prolongation : payée sur la trésorerie, sans toucher l'enveloppe.
    const pro = jeu.call('snapshot').squad.find(p => p.renewal?.available && p.renewal.fee > 0);
    assert.ok(pro, 'un joueur à prolonger');
    const cashPro = lire('club().cash');
    r = jeu.brut('extend_contract', { playerId: pro.id, salary: Math.min(100000, Math.ceil(pro.renewal.salary * 1.4 / 100) * 100), years: pro.renewal.minYears, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.ok(lire('club().cash') < cashPro, 'prime de prolongation payée');
    assert.equal(lire('S.budgetTransferts.depense'), libre.fee, 'une prolongation ne consomme rien');

    // 2 bis. Accord entre clubs hors budget : devis grisé, négociation non recevable, transfert refusé.
    let liste = devis(lire);
    const q = liste.candidates.filter(c => c.available && c.fee >= 100000 && c.fee <= 600000).sort((a, b) => a.fee - b.fee)[0];
    assert.ok(q, 'un accord possible entre clubs');
    fixer(v.enveloppe - (q.fee - 10000));
    const raisonIc = `Hors budget de transferts : il reste ${T.euros(q.fee - 10000)} sur l’enveloppe de ${T.euros(v.enveloppe)} fixée par le conseil.`;
    liste = devis(lire);
    const qg = liste.candidates.find(c => c.id === q.id);
    assert.equal(qg.available, false); assert.equal(qg.reason, raisonIc);
    const neg = jeu.call('interclub_negotiate', offre(q, liste.context)).meta.interclubNegotiation;
    assert.equal(neg.humanReady, false); assert.equal(neg.humanReason, raisonIc);
    const avantIc = lire('({cash:club().cash,n:club().players.length})');
    r = jeu.brut('interclub_transfer', { ...offre(q, liste.context), confirmed: true });
    assert.equal(r.ok, false); assert.match(r.error, /Hors budget de transferts : il reste/);
    assert.deepEqual(lire('({cash:club().cash,n:club().players.length})'), avantIc);

    // 5. Achat dans l'enveloppe qui fait passer la caisse sous la réserve : le président ne reprend pas la main.
    fixer(0);
    run(`club().cash=S.clubBudget.clubs[S.club].reserve+50000`);
    liste = devis(lire);
    const q2 = liste.candidates.find(c => c.id === q.id);
    assert.equal(q2.available, true, q2.reason);
    const avantAchat = lire('club().cash');
    r = jeu.brut('interclub_transfer', { ...offre(q2, liste.context), confirmed: true });
    assert.equal(r.ok, true, r.error);
    const apres = lire('({cash:club().cash,reserve:S.clubBudget.clubs[S.club].reserve,jour:CDWorldCareer.calendarToday(S),plan:S.presidentReprise?.clubs?.[S.club]??null})');
    assert.equal(apres.cash, avantAchat - q2.fee);
    assert.equal(lire(`nativePresidentReprise.declenche({avant:${avantAchat},apres:${apres.cash},reserve:${apres.reserve},date:'${apres.jour}'})`), true, 'sans l’exemption, il interviendrait');
    assert.equal(apres.plan, null, 'aucune intervention du président');
    assert.equal(lire('S.budgetTransferts.depense'), q2.fee, 'indemnité débitée de l’enveloppe');

    // Enchère perdue : rien n'est consommé.
    liste = devis(lire);
    let perdue = null;
    for (const c of liste.candidates.filter(c => c.available && c.fee >= 20000 && c.fee <= 300000)) {
      const n = jeu.call('interclub_negotiate', offre(c, liste.context)).meta.interclubNegotiation;
      if (n.winner && !n.winner.human) { perdue = { c, n }; break; }
    }
    assert.ok(perdue, 'une enchère gagnée par un autre club');
    const dep = lire('S.budgetTransferts.depense'), cashEnch = lire('club().cash');
    r = jeu.brut('interclub_auction', { ...offre(perdue.c, liste.context), expectedWinner: perdue.n.winner.clubId, expectedFee: perdue.n.winner.fee, expectedSalary: perdue.n.winner.salary, confirmed: true });
    assert.equal(r.ok, true, r.error); assert.equal(r.model.interclubTransfer?.humanWon ?? false, false);
    assert.equal(lire('S.budgetTransferts.depense'), dep); assert.equal(lire('club().cash'), cashEnch);

    // 4. Le disponible ne dépasse jamais caisse − matelas, même après une perte sans achat.
    fixer(0);
    v = vue();
    assert.ok(v.disponible <= lire('club().cash') - v.matelas);
    run(`club().cash=${v.matelas + 100000}`);
    assert.equal(vue().disponible, 100000);
    run(`club().cash=${v.matelas - 1}`);
    assert.equal(vue().disponible, 0);
    assert.equal(lire('budgetTransfertsRefus(1000)'), `La caisse ne permet plus de transfert : elle doit rester au-dessus de ${T.euros(v.matelas)}.`);
    m = jeu.call('snapshot');
    assert.ok(m.market.filter(p => p.fee > 0 && p.fee <= lire('club().cash')).every(p => !p.available), 'devis grisés');
    run(`club().cash=${avantAchat}`);

    // 6. Indemnité de formation reçue : +50 % ; vente choisie : +50 % ; ventes imposées (prêt, président) : rien.
    fixer(0, 0);
    const formation = lire(`(()=>{const d=nativeSystems.domain('formationFees');d.ensure(S);const p=club().players.find(x=>x.age<=23)||club().players[0];
      d.graduate(S,p,S.club);const autre=S.clubs.find(c=>c.id!==S.club).id;return d.settle(S,p,autre,false);})()`);
    assert.ok(formation > 0);
    assert.equal(lire('S.budgetTransferts.reconstitue'), Math.round(formation * P.partVentes));
    fixer(0, 0);
    const vente = lire(`(()=>{const lu=new Set([...S.lineup,...S.reserves]),j=club().players.filter(p=>!lu.has(p.id)&&!saleBlocked(p));
      const b=S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=500000);
      S.economy.offers.push({id:'bt-choisie',playerId:j[0].id,buyer:b.id,fee:200000,expires:S.economy.week});
      S.economy.offers.push({id:'bt-imposee',playerId:j[1].id,buyer:b.id,fee:200000,expires:S.economy.week});
      const a=acceptSale('bt-choisie'),r1=S.budgetTransferts.reconstitue;
      const c=budgetTransfertsImposee(()=>acceptSale('bt-imposee'));return {a,r1,c,r2:S.budgetTransferts.reconstitue};})()`);
    assert.deepEqual(vente, { a: true, r1: Math.round(200000 * P.partVentes), c: true, r2: Math.round(200000 * P.partVentes) });
    const president = lire(`(()=>{const c=club(),res=S.clubBudget.clubs[c.id].reserve,r0=S.budgetTransferts.reconstitue;S.presidentReprise={version:1,clubs:{},derniere:{}};
      c.cash=res-1.5e6;const ok=repriseApresAchat(c,res+1e6);const p=S.presidentReprise.clubs[c.id];p.echeance=CDWorldCareer.calendarToday(S);repriseSemaine();
      return {ok,etat:p.etat,r0,r1:S.budgetTransferts.reconstitue};})()`);
    assert.equal(president.ok, true); assert.equal(president.etat, 'vendu');
    assert.equal(president.r1, president.r0, 'une vente du président ne rend rien');

    // 7. Passage de saison : nouvelle enveloppe (ouverture des comptes), dépensé et reconstitué remis à 0.
    // Retouches sans sauvegarde à partir d'ici (les ventes simulées ci-dessus ne passent pas par une commande).
    jeu.bridge.vm.run('S.budgetTransferts.depense=123000;S.budgetTransferts.reconstitue=45000;');
    const saison = lire('S.season');
    const n = lire(`(()=>{S.trust=95;club().cash=S.clubBudget.clubs[S.club].reserve*2;S.season++;budgetOuvrir(true,true);
      return {e:S.budgetTransferts,attendu:budgetTransfertsNeuf().enveloppe};})()`);
    assert.equal(n.e.saison, saison + 1); assert.equal(n.e.depense, 0); assert.equal(n.e.reconstitue, 0);
    assert.ok(n.e.report > 0, 'report de la saison passée : ' + n.e.report);
    assert.equal(n.e.enveloppe, n.attendu);
    assert.notEqual(n.e.enveloppe, v.enveloppe, 'confiance et caisse ont changé : autre enveloppe');

    // R8 : changement de club : l'enveloppe de l'ancien club n'est pas reprise.
    const autre = lire(`(()=>{const e=S.budgetTransferts;e.depense=50000;const k=S.club;S.club=S.clubs.find(c=>c.id!==k&&budgetLigue(c.id)==='elite').id;
      const v=budgetTransfertsVue();S.club=k;return {v,clubId:S.budgetTransferts.clubId};})()`);
    assert.equal(autre.v.depense, 0); assert.equal(autre.clubId, CLUB, 'lecture seule');

    // Hors budget de saison (carrière non marquée) : règles inchangées, vue inactive.
    const hors = lire(`(()=>{const s=S.startingSalaries;delete S.startingSalaries;const r={v:budgetTransfertsVue(),refus:budgetTransfertsRefus(9e9)};S.startingSalaries=s;return r;})()`);
    assert.equal(hors.v.actif, false); assert.equal(hors.refus, null);
  } finally { jeu.fermer(); }
});

test('Moteur Monde : rallonge accordée, refusée (confiance, part, plafond), caisse limitante, report et changement de club', { timeout: 300000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let m = creer(jeu, CLUB);
    const { run, lire, vue } = outils(jeu);
    const v0 = m.finance.transferBudget;
    const demander = amount => jeu.brut('transfer_budget_extension', { amount, confirmed: true });
    const etat = () => lire('S.budgetTransferts');
    const nouvelles = () => lire('JSON.stringify(S.news.slice(0,3))');

    // Joueur libre refusé par l'enveloppe (la caisse ne limite pas) : il manque 1 500 €, la rallonge demandée est de 2 000 €.
    const libre = m.market.find(p => p.available && p.maxYears >= 2 && p.fee >= 3000);
    assert.ok(libre, 'un joueur libre recrutable');
    run(`(()=>{const e=budgetTransfertsEtat(true);e.depense=e.enveloppe-(${libre.fee}-1500);S.trust=72;})()`);
    m = jeu.call('snapshot');
    let v = m.finance.transferBudget, piste = m.market.find(p => p.id === libre.id);
    assert.equal(piste.available, false);
    assert.equal(piste.reason, `Hors budget de transferts : il reste ${T.euros(libre.fee - 1500)} sur l’enveloppe de ${T.euros(v.enveloppe)} fixée par le conseil.`, 'la caisse permettrait l’offre : pas de mention de la caisse');
    assert.equal(v.reste, libre.fee - 1500); assert.ok(v.caisseLibre >= libre.fee);
    assert.equal(T.demandeRallonge(etat(), libre.fee, lire('club().cash'), v.matelas), 2000);
    assert.equal(Math.ceil((libre.fee - v.reste) / v.rallongeArrondi) * v.rallongeArrondi, 2000, 'calcul repris par l’interface');

    // Demande invalide : rien n'est écrit.
    let r = jeu.brut('transfer_budget_extension', { amount: 2000 });
    assert.equal(r.ok, false); assert.match(r.error, /Confirme/);
    r = demander(1500);
    assert.equal(r.ok, false); assert.match(r.error, /invalide/);
    assert.equal(etat().demandes, 0); assert.equal(lire('S.trust'), 72);

    // Refusée pour confiance basse : −1 de confiance, demande comptée, pas de rallonge, ligne dans les nouvelles.
    const bas = Q.confianceMin - 15, cA = Q.coutAccordee, cR = Q.coutRefusee;
    run(`S.trust=${bas}`);
    r = demander(2000);
    assert.equal(r.ok, true, r.error);
    let rep = r.model.meta.transferBudgetExtension;
    assert.deepEqual(rep, { accordee: false, montant: 2000, message: `Le président refuse : sa confiance (${bas}/100) est trop basse pour rouvrir l’enveloppe ; il en faut ${Q.confianceMin}.`, confiance: bas - cR, coutConfiance: cR });
    assert.equal(lire('S.trust'), bas - cR);
    assert.deepEqual([etat().demandes, etat().rallongesAccordees, etat().rallonge], [1, 0, 0]);
    assert.match(nouvelles(), /Budget de transferts : demande de rallonge de 2 000 € refusée\. Le président refuse : sa confiance/);
    assert.equal(r.model.market.find(p => p.id === libre.id).available, false);

    // Accordée : −3 de confiance, la rallonge s'ajoute à l'enveloppe de la saison, l'offre devient possible.
    run('S.trust=72');
    r = demander(2000);
    assert.equal(r.ok, true, r.error);
    rep = r.model.meta.transferBudgetExtension;
    assert.deepEqual(rep, { accordee: true, montant: 2000, message: 'Le conseil accorde une rallonge de 2 000 € au budget de transferts.', confiance: 72 - cA, coutConfiance: cA });
    v = r.model.finance.transferBudget;
    assert.deepEqual([v.rallonge, v.demandes, v.rallongesAccordees, v.reste], [2000, 2, 1, libre.fee + 500]);
    assert.equal(v.disponible, Math.min(v.reste, v.caisseLibre));
    assert.match(nouvelles(), /Budget de transferts : le conseil accorde une rallonge de 2 000 €\./);
    piste = r.model.market.find(p => p.id === libre.id);
    assert.equal(piste.available, true, piste.reason);
    const salaire = Math.min(100000, Math.ceil(libre.salary * 1.4 / 100) * 100);
    r = jeu.brut('recruit', { playerId: libre.id, salary: salaire, years: 2, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(vue().reste, 500, 'la rallonge a servi à la signature');

    // Refusée : plus de 50 % de l'enveloppe fixée.
    assert.ok(Q.maxParSaison === 2 && Q.confianceMin <= 72 - cA - cR,'réglages attendus par ce scénario : deux rallonges, confiance suffisante');
    const trop = Math.floor(v0.enveloppe * Q.partEnveloppe / 1000) * 1000 + 1000;
    r = demander(trop);
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.transferBudgetExtension.accordee, false);
    assert.match(r.model.meta.transferBudgetExtension.message, new RegExp(`dépassent ${Math.round(Q.partEnveloppe * 100)} % de l’enveloppe fixée en début de saison`));
    assert.equal(lire('S.trust'), 72 - cA - cR);

    // Plafond : le nombre de rallonges accordées par saison est limité, la suivante est refusée.
    r = demander(1000); assert.equal(r.model.meta.transferBudgetExtension.accordee, true);
    assert.equal(etat().rallongesAccordees, 2);
    r = demander(1000);
    assert.equal(r.model.meta.transferBudgetExtension.accordee, false);
    assert.equal(r.model.meta.transferBudgetExtension.message, `Le président refuse : le conseil a déjà accordé ${Q.maxParSaison} rallonges cette saison.`);
    assert.deepEqual([etat().demandes, etat().rallongesAccordees, etat().rallonge], [5, 2, 3000]);
    assert.equal(lire('S.trust'), 72 - cA - cR - cA - cR, 'part refusée, accordée, plafond refusé');

    // Caisse limitante : pas de rallonge possible, la commande est refusée sans rien écrire.
    v = vue();
    run(`club().cash=${v.matelas + v.reste}`);
    const avant = { e: etat(), trust: lire('S.trust') };
    r = demander(1000);
    assert.equal(r.ok, false); assert.match(r.error, /Pas de rallonge possible : c’est la caisse qui limite/);
    assert.deepEqual({ e: etat(), trust: lire('S.trust') }, avant);
    assert.equal(vue().disponible, v.reste);
    run(`club().cash=${v.matelas * 3}`);

    // Report au passage de saison : 25 % du reste non dépensé, rallonges remises à zéro ; visible dans la vue.
    jeu.bridge.vm.run('S.budgetTransferts.depense=Math.round(S.budgetTransferts.enveloppe/2);S.budgetTransferts.reconstitue=20000;');
    const fin = etat(), recettes = lire('budgetTransfertsEntrees().recettes');
    const n = lire(`(()=>{S.season++;budgetOuvrir(true,true);return {e:S.budgetTransferts,v:budgetTransfertsVue()};})()`);
    const attendu = T.report(fin, n.e.enveloppe, recettes);
    const pasR = Q.arrondi;
    assert.equal(attendu, Math.min(Math.floor(P.partReport * T.reste(fin) / pasR) * pasR, Math.floor((recettes * P.plafond - n.e.enveloppe) / pasR) * pasR));
    assert.ok(attendu > 0);
    assert.deepEqual([n.e.report, n.e.rallonge, n.e.demandes, n.e.rallongesAccordees, n.e.depense], [attendu, 0, 0, 0, 0]);
    assert.equal(n.v.report, attendu); assert.equal(n.v.reste, n.e.enveloppe + attendu);
    // Refixée dans la même saison : le report est gardé.
    assert.equal(lire('(()=>{budgetOuvrir(true,true);return S.budgetTransferts.report;})()'), attendu);

    // Changement de club : l'ancienne enveloppe ne se reporte pas.
    const sans = lire(`(()=>{const k=S.club,autre=S.clubs.find(c=>c.id!==k&&budgetLigue(c.id)==='elite').id;S.budgetTransferts.clubId=autre;
      S.season++;budgetOuvrir(true,true);return S.budgetTransferts;})()`);
    assert.equal(sans.clubId, CLUB); assert.equal(sans.report, 0, 'pas de report depuis un autre club');
  } finally { jeu.fermer(); }
});

test('Critère 8 : carrière antérieure sans enveloppe : calculée à la lecture, sans erreur ni réécriture', { timeout: 300000 }, () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-budget-transferts-'));
  try {
    const jeu = ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      creer(jeu, CLUB);
      jeu.bridge.vm.run('delete S.budgetTransferts');
      jeu.call('save');
    } finally { jeu.fermer(); }
    const repris = ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      const lire = s => JSON.parse(repris.bridge.vm.run('JSON.stringify(' + s + ')'));
      assert.equal(lire('S.budgetTransferts === undefined'), true, 'sauvegarde sans enveloppe');
      const v = repris.call('snapshot').finance.transferBudget;
      assert.equal(v.actif, true); assert.ok(v.enveloppe > 0); assert.equal(v.depense, 0); assert.equal(v.reconstitue, 0);
      assert.equal(v.enveloppe, T.enveloppe(lire('budgetTransfertsEntrees()')));
      assert.equal(lire('S.budgetTransferts === undefined'), true, 'aucune écriture à la lecture');
      const r = repris.brut('export', {});
      assert.equal(r.ok, true, r.error);
      assert.equal(JSON.parse(r.model.meta.exportText).state.budgetTransferts, undefined, 'sauvegarde inchangée');
    } finally { repris.fermer(); }
  } finally { fs.rmSync(dataDir, { recursive: true, force: true }); }
});
