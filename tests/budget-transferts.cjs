'use strict';
// Budget de transferts (native/engine/budget-transferts.cjs, docs/gdd/budget-transferts.md) : enveloppe fixée par le
// conseil, refus avant signature, débit des primes et indemnités, matelas de la caisse, exemption de la reprise du
// président, recettes (formation +50 %, ventes imposées 0), passage de saison, carrière antérieure, réglages JSON.
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

test('Formule : exemple du GDD (Castres), plancher, plafond, matelas, refus et part des ventes', () => {
  const castres = { recettes: 29.6e6, division: 'elite', type: 'entreprise', confiance: 72, cash: 3.7e6, reserve: 3.78e6 };
  assert.equal(T.enveloppe(castres), 640000, 'GDD : ≈ 640 000 €');
  assert.equal(T.matelas(3.78e6), 1890000);
  assert.equal(T.matelas(null), 400000, 'réserve illisible : matelas fixe');
  assert.equal(T.matelas(0.5e6), 400000);
  // Confiance 0 : facteur 0,75, jamais zéro ; caisse vide : plancher 0,5 % des recettes.
  assert.equal(T.enveloppe({ ...castres, confiance: 0, cash: 0 }), Math.round(29.6e6 * 0.02 * 0.75 * 0.5 / 10000) * 10000, 'facteurs au minimum');
  assert.equal(T.enveloppe({ ...castres, division: 'accession', type: 'association', confiance: 0, cash: 0 }), Math.round(29.6e6 * 0.005 / 10000) * 10000, 'plancher');
  assert.ok(T.enveloppe({ ...castres, type: 'mecene', confiance: 100, cash: 99e6 }) <= 29.6e6 * 0.06 + 5000, 'plafond 6 %');
  // Pro D2 / autres championnats : taux propre ou défaut.
  assert.ok(T.enveloppe({ ...castres, division: 'accession' }) < T.enveloppe(castres));
  assert.equal(T.enveloppe({ ...castres, division: 'prem' }), T.enveloppe({ ...castres, division: 'accession' }), 'taux par défaut');
  const e = { enveloppe: 1160000, depense: 920000, reconstitue: 0 };
  assert.equal(T.refus(e, 240000, 9e6, 1.89e6), null, 'pile le reste');
  assert.equal(T.refus(e, 240001, 9e6, 1.89e6), 'Hors budget de transferts : il reste 240 000 € sur l’enveloppe de 1 160 000 € fixée par le conseil.');
  assert.equal(T.refus(e, 100000, 1.9e6, 1.89e6), 'La caisse ne permet plus de transfert : elle doit rester au-dessus de 1 890 000 €.');
  assert.equal(T.disponible(e, 1e6, 1.89e6), 0, 'caisse sous le matelas : 0, jamais négatif');
  assert.equal(T.rendu({ enveloppe: 640000, reconstitue: 0 }, 300000, 29.6e6), 150000, '50 % d’une vente choisie');
  assert.equal(T.rendu({ enveloppe: 1.7e6, reconstitue: 0 }, 1e6, 29.6e6), 29.6e6 * 0.06 - 1.7e6, 'plafonné à 6 % des recettes');
});

test('Critère 9 : changer les valeurs du JSON change l’enveloppe sans modifier le code', () => {
  const x = { recettes: 29.6e6, division: 'elite', type: 'entreprise', confiance: 72, cash: 3.7e6, reserve: 3.78e6 };
  const avant = T.enveloppe(x), taux = R.taux.elite;
  try {
    R.taux.elite = taux * 1.5;
    assert.equal(T.enveloppe(x), Math.round(avant * 1.5 / 10000) * 10000);
    R.taux.elite = taux; R.ambition.entreprise = 0.5;
    assert.equal(T.enveloppe(x), Math.round(avant * 0.5 / 10000) * 10000);
  } finally { R.taux.elite = taux; R.ambition.entreprise = 1; }
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
    assert.deepEqual(Object.keys(v).sort(), ['actif', 'depense', 'disponible', 'enveloppe', 'matelas', 'reconstitue', 'saison']);
    assert.equal(v.actif, true);
    assert.equal(v.enveloppe, T.enveloppe(x));
    assert.deepEqual(lire('S.budgetTransferts'), { version: 1, saison: v.saison, clubId: CLUB, enveloppe: v.enveloppe, depense: 0, reconstitue: 0 }, 'fixée à la création');
    assert.ok(v.disponible >= x.recettes * 0.005 && v.disponible <= x.recettes * 0.06, 'disponible ' + v.disponible);
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
    assert.equal(lire('S.budgetTransferts.reconstitue'), Math.round(formation * 0.5));
    fixer(0, 0);
    const vente = lire(`(()=>{const lu=new Set([...S.lineup,...S.reserves]),j=club().players.filter(p=>!lu.has(p.id)&&!saleBlocked(p));
      const b=S.clubs.find(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=500000);
      S.economy.offers.push({id:'bt-choisie',playerId:j[0].id,buyer:b.id,fee:200000,expires:S.economy.week});
      S.economy.offers.push({id:'bt-imposee',playerId:j[1].id,buyer:b.id,fee:200000,expires:S.economy.week});
      const a=acceptSale('bt-choisie'),r1=S.budgetTransferts.reconstitue;
      const c=budgetTransfertsImposee(()=>acceptSale('bt-imposee'));return {a,r1,c,r2:S.budgetTransferts.reconstitue};})()`);
    assert.deepEqual(vente, { a: true, r1: 100000, c: true, r2: 100000 });
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
