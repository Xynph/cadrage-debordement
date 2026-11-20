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
  const ecart = budget.recettesImprevues(ecritures, {forces:args.forces, clubId:args.clubId, receptions:args.receptions, accueil:args.accueil});
  const frais = budget.fraisDeMatch(capture.compte, ecart, budget.deficitPrevu(args.forces, args.clubId, args.masseHebdo * 52));
  if (frais.montant > 0) ecritures.push({title:args.libelle + ' · ' + budget.LIBELLE_FRAIS_MATCH, amount:-frais.montant});
  return ecritures;
}
function reconcile(before, after, trace) {
  if (before.season !== after.season || after.week !== before.week + 1 || before.mode !== 'world-champ' || after.mode !== 'world-champ')
    throw Error('Audit limited to one ordinary world-champ week, no interseason');
  if (!trace || !Array.isArray(trace.writes) || !trace.billing) throw Error('Audit requires the traced engine writes of the week');
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
    if (c.id === before.club) {
      // Grand livre du club joué : la queue commune des deux livres donne les écritures de la semaine.
      let added = null;
      for (let n = 0; n <= after.ledger.length; n++) {
        const tail = after.ledger.slice(n);
        if (tail.length && same(tail, before.ledger.slice(0, tail.length))) { added = after.ledger.slice(0, n); break; }
      }
      if (!before.ledger.length) added = after.ledger;
      const observed = added ? sum(added.map(x => x.amount)) : null;
      return {clubId:c.id, kind:'human-ledger', delta, traced, conserved, ledger:added, observedLedgerDelta:observed,
        residual:observed === null ? null : delta - observed,
        status:conserved && observed !== null && delta === observed ? 'reconciled-ledger' : 'unknown'};
    }
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
    const reconciled = conserved && !!billing && billing.matched && transfers.matched && !unknownWrites.length && humanFlow === 0 && residual === 0;
    return {clubId:c.id, kind:'ai', delta, traced, conserved, billing, transfers, unknownWrites, residual,
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
      delta:sum(ai.map(r => r.delta)), residual:sum(ai.map(r => r.residual))}};
}
module.exports = {reconcile, billingReplay, upkeep, wages, FLOWS};
