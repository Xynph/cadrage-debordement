'use strict';
// Relecture des flux financiers d'une semaine ordinaire de carrière Monde (world-champ), budget de saison
// réaliste compris (actif par défaut depuis #699). Lecture seule : ce module ne remplace pas l'économie, il
// rejoue les fonctions de production (barème du budget, entretien des installations) et rapproche chaque
// variation de caisse d'une écriture tracée. Une variation sans flux connu reste « unknown » : aucune
// attribution inventée (transfert, dette, investissement…).
//
// Entrées : deux états (avant / après la clôture de la semaine) et la trace de la semaine relevée dans le
// moteur par ci/world-finance-flow-audit.cjs :
//   writes  : [{clubId, delta, fn}] chaque écriture de `cash`, avec la fonction du moteur qui l'a faite ;
//   billing : {clubId: {args, ecritures, compte}} : arguments du barème (club-budget.semaine), écritures
//             rendues par budgetSemaine (frais de match compris) et compteur du club avant la semaine.
const facilities = require('../../dist/facilities.js');
const budget = require('./club-budget.cjs');
const owner = require('./club-owner.cjs');
const investments = require('./club-investments.cjs');
const sum = xs => xs.reduce((n, x) => n + x, 0);
const wages = c => sum(c.players.map(p => p.salary));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
// Même calcul que worldUpkeep (dist/world-career.js) : le niveau 2 de départ ne coûte rien.
function upkeep(level) {
  return level <= 2 ? 0 : Math.round(facilities.maintenanceForecast({cash:0, levels:[level], weeks:1, baseWeekly:2000}).weekly);
}
// Flux connus, par fonction du moteur qui écrit la caisse.
const FLOWS = Object.freeze({
  worldWeeklyEconomy: 'billing',      // facturation hebdomadaire (barème V1 puis budget de saison réaliste)
  calIANouvelAccord: 'transfer',      // accord entre deux clubs gérés (indemnité payée à l'accord)
  financeWeek: 'human-week',          // semaine du club joué (grand livre)
});
// Écritures du barème rejouées hors du moteur : club-budget.semaine (module de production, figé), puis
// les frais de match des recettes imprévues comme budgetSemaine les ajoute en mode Monde.
function billingReplay(capture, {extraWeeklyWages = 0} = {}) {
  const args = {...capture.args, masseHebdo: capture.args.masseHebdo + extraWeeklyWages};
  const ecritures = budget.semaine(args);
  const ecart = budget.recettesImprevues(ecritures, {forces:args.forces, clubId:args.clubId, receptions:args.receptions, accueil:args.accueil, billets:args.billets});
  const frais = budget.fraisDeMatch(capture.compte, ecart, budget.deficitPrevu(args.forces, args.clubId, args.masseHebdo * 52));
  if (frais.montant > 0) ecritures.push({title:args.libelle + ' · ' + budget.LIBELLE_FRAIS_MATCH, amount:-frais.montant});
  // Investissements des excédents (club-investments.cjs) : une ligne par chantier, même total, selon la
  // répartition du club pour la saison.
  const i = capture.invest ? ecritures.findIndex(e => /Investissements \(excédents réinvestis\)$/.test(e.title)) : -1;
  if (i >= 0) {
    const tranche = investments.decouper(-ecritures[i].amount, capture.invest.parts);
    ecritures.splice(i, 1, ...investments.PARTS.filter(k => tranche[k] > 0).map(k => ({title:args.libelle + ' · Investissements : ' + investments.LIBELLES[k], amount:-tranche[k]})));
  }
  return ecritures;
}
// Grand livre du club joué : la queue commune des deux livres donne les écritures de la période.
function humanRow(clubId, before, after, delta, traced, conserved) {
  let added = null;
  for (let n = 0; n <= after.ledger.length; n++) {
    const tail = after.ledger.slice(n);
    if (tail.length && same(tail, before.ledger.slice(0, tail.length))) { added = after.ledger.slice(0, n); break; }
  }
  if (!before.ledger.length) added = after.ledger;
  const observed = added ? sum(added.map(x => x.amount)) : null;
  return {clubId, kind:'human-ledger', delta, traced, conserved, ledger:added, observedLedgerDelta:observed,
    residual:observed === null ? null : delta - observed,
    status:conserved && observed !== null && delta === observed ? 'reconciled-ledger' : 'unknown'};
}
function reconcile(before, after, trace) {
  if (before.season !== after.season || after.week !== before.week + 1 || before.mode !== 'world-champ' || after.mode !== 'world-champ')
    throw Error('Audit limited to one ordinary world-champ week, no interseason');
  if (!trace || !Array.isArray(trace.writes) || !Array.isArray(trace.debts) || !trace.billing || !before.debt || !after.debt)
    throw Error('Audit requires the traced engine writes (cash and debt) of the week');
  const beforeAccords = new Set((before.accordsIA || []).map(a => a.id));
  const accords = (after.accordsIA || []).filter(a => !beforeAccords.has(a.id));
  const rows = before.clubs.map(c => {
    const next = after.clubs.find(n => n.id === c.id);
    const delta = next.cash - c.cash;
    const writes = trace.writes.filter(w => w.clubId === c.id);
    const traced = sum(writes.map(w => w.delta));
    const byFlow = {};
    for (const w of writes) { const flow = FLOWS[w.fn] || 'unknown'; byFlow[flow] = (byFlow[flow] || 0) + w.delta; }
    const unknownWrites = writes.filter(w => !FLOWS[w.fn]).map(w => ({fn:w.fn, delta:w.delta}));
    const conserved = traced === delta;
    if (c.id === before.club) return humanRow(c.id, before, after, delta, traced, conserved);
    const capture = trace.billing[c.id];
    let billing = null;
    if (capture) {
      const replay = billingReplay(capture);
      const replayMatchesEngine = same(replay, capture.ecritures);
      const expected = sum(replay.map(e => e.amount)) - upkeep(before.facilities[c.id]);
      billing = {expected, observed:byFlow.billing || 0, replayMatchesEngine, components:replay,
        upkeep:-upkeep(before.facilities[c.id])};
      billing.matched = replayMatchesEngine && billing.expected === billing.observed;
    }
    // Indemnités des accords conclus cette semaine : payées par l'acheteur, reçues par le vendeur.
    const mine = accords.filter(a => a.acheteurId === c.id || a.vendeurId === c.id);
    const transferExpected = sum(mine.map(a => (a.vendeurId === c.id ? a.montant : 0) - (a.acheteurId === c.id ? a.montant : 0)));
    const transfers = {expected:transferExpected, observed:byFlow.transfer || 0, accords:mine.map(a => a.id)};
    transfers.matched = transfers.expected === transfers.observed;
    const humanFlow = byFlow['human-week'] || 0;
    const residual = delta - (billing ? billing.expected : 0) - transfers.expected;
    // Dette : seul le remboursement du prêt de l'actionnaire la fait bouger en semaine (pretRembourser, appelé
    // par la facturation). Elle baisse exactement de l'écriture « Remboursement du prêt » rejouée, et l'encours
    // enregistré du prêt (pretsActionnaires) baisse d'autant.
    const debts = trace.debts.filter(w => w.clubId === c.id);
    const debtDelta = after.debt[c.id] - before.debt[c.id], debtConserved = sum(debts.map(w => w.delta)) === debtDelta;
    const repaid = billing ? sum(billing.components.filter(e => e.title.endsWith(' · ' + budget.LIBELLE_REMBOURSEMENT)).map(e => e.amount)) : 0;
    const restant = s => s.prets?.[c.id]?.restant ?? 0;
    const loan = {expected:repaid, observed:sum(debts.filter(w => w.fn === 'pretRembourser').map(w => w.delta)),
      outstandingBefore:restant(before), outstandingAfter:restant(after)};
    loan.matched = loan.expected === loan.observed && loan.outstandingAfter === loan.outstandingBefore + repaid;
    const unknownDebts = debts.filter(w => w.fn !== 'pretRembourser').map(w => ({fn:w.fn, delta:w.delta}));
    const reconciled = conserved && !!billing && billing.matched && transfers.matched && !unknownWrites.length && humanFlow === 0 && residual === 0
      && debtConserved && loan.matched && !unknownDebts.length;
    return {clubId:c.id, kind:'ai', delta, traced, conserved, billing, transfers, unknownWrites, residual, debtDelta, debtConserved, loan, unknownDebts,
      payrollBefore:wages(c), payrollAfter:wages(next),
      status:reconciled ? 'reconciled' : 'unknown',
      ...(reconciled ? {} : {note:'Untraced write, unknown engine flow or residual: no invented attribution.'})};
  });
  const ai = rows.filter(r => r.kind === 'ai');
  return {season:before.season, week:before.week, rows,
    accords:accords.map(a => ({id:a.id, vendeurId:a.vendeurId, acheteurId:a.acheteurId, montant:a.montant})),
    ai:{clubs:ai.length, reconciled:ai.filter(r => r.status === 'reconciled').length,
      unknown:ai.filter(r => r.status === 'unknown').length,
      billingMatched:ai.filter(r => r.billing?.matched).length,
      transferClubs:ai.filter(r => r.transfers.accords.length).length,
      transferNet:sum(ai.map(r => r.transfers.observed)),
      loanRepayments:sum(ai.map(r => r.loan.observed)), loanClubs:ai.filter(r => r.loan.observed).length,
      delta:sum(ai.map(r => r.delta)), residual:sum(ai.map(r => r.residual))}};
}
// Intersaison (commande « Saison suivante ») : chaque fonction du moteur qui écrit la caisse ou la dette d'un club
// géré est rapprochée de son propre enregistrement. Fonction → montant attendu pour le club :
//   budgetCloturer             clôture des comptes rejouée (club-budget.cloture : prime de classement, amende,
//                              apport du propriétaire), résultat identique à celui du moteur ;
//   pretAccorder (dette)       apport du propriétaire transformé en prêt : la dette monte de l'apport ;
//   worldPrepareRenewalLiquidity, worldNewSeason   caisse négative passée en dette (caisse et dette montent
//                              d'autant), remboursement (les deux baissent d'autant), installations : la caisse
//                              baisse en plus du coût des niveaux achetés (worldManagement.upgrades) ;
//   budgetOuvrir               dividende versé au groupe actionnaire (budget de la nouvelle saison) ;
//   aiRosterContracts, aiRosterRecruitmentWeek     indemnités des renouvellements et recrutements déclarés par la
//                              même fonction (événements d'effectif) ;
//   calIANouvelAccord          accords conclus (accordsIA) ; settle : indemnités de formation (formationFees) ;
//   closeSeason                fonds JIFF et amendes EQP de la saison close (jiff.results).
// Tout autre flux, ou une dette qui bouge autrement (intérêts d'une dette de crise…), laisse le club « unknown ».
const added = (b, a, key) => { const seen = new Set((b[key] || []).map(x => JSON.stringify(x))); return (a[key] || []).filter(x => !seen.has(JSON.stringify(x))); };
const DEBT_FLOWS = ['pretAccorder', 'worldPrepareRenewalLiquidity', 'worldNewSeason'];
function reconcileInterseason(before, after, trace) {
  if (before.mode !== 'world-champ' || after.mode !== 'world-champ' || before.phase !== 'ended' || after.season !== before.season + 1)
    throw Error('Interseason audit covers exactly one world-champ season change');
  if (!trace || !Array.isArray(trace.writes) || !Array.isArray(trace.debts) || !trace.closing || !Array.isArray(trace.events))
    throw Error('Audit requires the traced engine writes of the interseason');
  const accords = added(before, after, 'accordsIA'), fees = added(before, after, 'formationFees');
  const jiff = added(before, after, 'jiff').filter(x => x.season === before.season);
  const upgrades = added(before, after, 'upgrades').filter(u => u.season === after.season);
  const rows = before.clubs.map(c => {
    const next = after.clubs.find(n => n.id === c.id), delta = next.cash - c.cash;
    const writes = trace.writes.filter(w => w.clubId === c.id), debts = trace.debts.filter(w => w.clubId === c.id);
    const traced = sum(writes.map(w => w.delta)), conserved = traced === delta;
    if (c.id === before.club) return humanRow(c.id, before, after, delta, traced, conserved);
    const debtDelta = after.debt[c.id] - before.debt[c.id], debtConserved = sum(debts.map(w => w.delta)) === debtDelta;
    const cashBy = fn => sum(writes.filter(w => w.fn === fn).map(w => w.delta));
    const debtBy = fn => sum(debts.filter(w => w.fn === fn).map(w => w.delta));
    const fee = fn => sum(trace.events.filter(e => e.clubId === c.id && e.fn === fn && ['renew', 'recruit'].includes(e.kind)).map(e => e.fee));
    const capture = trace.closing[c.id];
    let closing = null;
    if (capture) {
      const replay = budget.cloture(capture.args);
      closing = {replayMatchesEngine:same(replay, capture.result), apport:replay.apport, prime:replay.prime, amende:replay.amende,
        expected:sum(replay.ecritures.map(e => e.amount))};
    }
    const upgradeCost = sum(upgrades.filter(u => u.id === c.id).map(u => u.cost));
    const flows = {
      budgetCloturer:{expected:closing ? closing.expected : null, observed:cashBy('budgetCloturer')},
      worldPrepareRenewalLiquidity:{expected:debtBy('worldPrepareRenewalLiquidity'), observed:cashBy('worldPrepareRenewalLiquidity')},
      worldNewSeason:{expected:debtBy('worldNewSeason') - upgradeCost, observed:cashBy('worldNewSeason'), upgradeCost},
      budgetOuvrir:{expected:-(after.dividends[c.id] || 0), observed:cashBy('budgetOuvrir')},
      aiRosterContracts:{expected:-fee('aiRosterContracts'), observed:cashBy('aiRosterContracts')},
      aiRosterRecruitmentWeek:{expected:-fee('aiRosterRecruitmentWeek'), observed:cashBy('aiRosterRecruitmentWeek')},
      calIANouvelAccord:{expected:sum(accords.map(a => (a.vendeurId === c.id ? a.montant : 0) - (a.acheteurId === c.id ? a.montant : 0))), observed:cashBy('calIANouvelAccord')},
      settle:{expected:sum(fees.map(f => (f.to === c.id ? f.amount : 0) - (f.from === c.id ? f.amount : 0))), observed:cashBy('settle')},
      closeSeason:{expected:sum(jiff.filter(x => x.clubId === c.id).map(x => (x.bonus || 0) - (x.fine || 0))), observed:cashBy('closeSeason')},
    };
    for (const f of Object.values(flows)) f.matched = f.expected === f.observed;
    // Prêt de l'actionnaire (club-owner.cjs) : seul un propriétaire prêteur transforme l'apport en prêt, dans la limite
    // de ce qu'il accorde (accorder, rejoué sur le prêt en cours) ; l'encours enregistré doit être celui du rejeu.
    const lender = !!closing && closing.apport > 0 && owner.preteur(c.id, capture.args.compte.type);
    const granted = lender ? owner.accorder(before.prets?.[c.id] ?? null, closing.apport, before.budgetSeason, capture.args.compte.enveloppe) : null;
    const loan = {expected:granted ? granted.prete : 0, observed:debtBy('pretAccorder'), lender};
    if (granted?.prete > 0 && !same(after.prets?.[c.id], granted.pret)) loan.recordMismatch = true;
    loan.matched = loan.expected === loan.observed && !loan.recordMismatch;
    const unknownWrites = writes.filter(w => !(w.fn in flows)).map(w => ({fn:w.fn, delta:w.delta}));
    const unknownDebts = debts.filter(w => !DEBT_FLOWS.includes(w.fn)).map(w => ({fn:w.fn, delta:w.delta}));
    const residual = delta - sum(Object.values(flows).map(f => f.expected ?? 0));
    const reconciled = conserved && debtConserved && !!closing && closing.replayMatchesEngine && Object.values(flows).every(f => f.matched)
      && loan.matched && !unknownWrites.length && !unknownDebts.length && residual === 0;
    return {clubId:c.id, kind:'ai', delta, traced, conserved, debtDelta, debtConserved, closing, flows, loan, unknownWrites, unknownDebts, residual,
      status:reconciled ? 'reconciled' : 'unknown', ...(reconciled ? {} : {note:'Untraced write, unknown engine flow or residual: no invented attribution.'})};
  });
  const ai = rows.filter(r => r.kind === 'ai'), total = fn => sum(ai.map(r => r.flows[fn].observed));
  return {season:before.season, interseason:true, rows, accords:accords.length, formationFees:fees.length,
    // Indemnités de formation nettes du club joué (reçues − versées) : la part des clubs gérés en est l'opposé.
    humanFormationFees:sum(fees.map(f => (f.to === before.club ? f.amount : 0) - (f.from === before.club ? f.amount : 0))), jiff:jiff.length, upgrades:upgrades.length,
    ai:{clubs:ai.length, reconciled:ai.filter(r => r.status === 'reconciled').length, unknown:ai.filter(r => r.status === 'unknown').length,
      closingReplayed:ai.filter(r => r.closing?.replayMatchesEngine).length, loans:sum(ai.map(r => r.loan.observed)),
      flows:Object.fromEntries(Object.keys(ai[0].flows).map(fn => [fn, total(fn)])),
      transferNet:total('calIANouvelAccord'), delta:sum(ai.map(r => r.delta)), residual:sum(ai.map(r => r.residual))}};
}
module.exports = {reconcile, reconcileInterseason, billingReplay, upkeep, wages, FLOWS};
