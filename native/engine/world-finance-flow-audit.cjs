'use strict';
// Read-only reconciliation, not an alternative economy implementation.
const facilities = require('../../dist/facilities.js');
const sum = xs => xs.reduce((n, x) => n + x, 0);
const wages = c => sum(c.players.map(p => p.salary));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
function upkeep(level) {
  return level <= 2 ? 0 : Math.round(facilities.maintenanceForecast({cash:0, levels:[level], weeks:1, baseWeekly:2000}).weekly);
}
function won(result, id) {
  const side = result.pair.indexOf(id);
  return result.phase && result.phase !== 'league' && result.winner !== undefined
    ? result.winner === id : result.score[side] > result.score[1-side];
}
function reconcile(before, after) {
  if (before.season !== after.season || after.round !== before.round + 1 || before.worldMode?.version !== 1)
    throw Error('Audit limited to one ordinary world-v1 week, no interseason');
  const results = after.history.filter(r => !before.history.some(p => p.fixtureId === r.fixtureId));
  const rows = before.clubs.map(c => {
    const next = after.clubs.find(n => n.id === c.id);
    const oldInfo = before.worldManagement.clubInfo.find(i => i.id === c.id);
    const newInfo = after.worldManagement.clubInfo.find(i => i.id === c.id);
    const delta = next.cash - c.cash;
    if (c.id === before.club) {
      // Find the shared ledger tail; do not label the human's random tickets as AI revenue.
      let added = null;
      for (let n=0; n<=after.ledger.length; n++) {
        const tail = after.ledger.slice(n);
        if (tail.length && same(tail, before.ledger.slice(0,tail.length))) { added = after.ledger.slice(0,n); break; }
      }
      if (!before.ledger.length) added = after.ledger;
      const observed = added ? sum(added.map(x => x.amount)) : null;
      const labels={partners:' · Partenaires',wages:' · Salaires',tickets:' · Billetterie',winBonus:' · Prime de victoire',upkeep:' · Entretien des installations'};
      const componentsObserved=added?Object.fromEntries(Object.entries(labels).map(([key,suffix])=>[key,sum(added.filter(x=>x.title.endsWith(suffix)).map(x=>x.amount))])):null;
      const otherLedgerEntries=added?.filter(x=>!Object.values(labels).some(suffix=>x.title.endsWith(suffix)))??null;
      return {clubId:c.id,kind:'human-ledger',delta,ledger:added,observedLedgerDelta:observed,componentsObserved,otherLedgerEntries,
        residual:observed === null ? null : delta-observed,status:observed !== null && delta===observed ? 'reconciled-ledger' : 'unknown',
        note:'Human tickets use rand(300,450)*1000; sponsor/other ledger entries retained, no fixed AI ticket assumption.'};
    }
    const own = results.find(r => r.pair.includes(c.id));
    const home = results.some(r => r.pair[0] === c.id && !r.neutral);
    const components = {partners:160000,tickets:home?360000:0,winBonus:own&&won(own,c.id)?80000:0,wages:-wages(c),upkeep:-upkeep(oldInfo.facilities)};
    const expected = sum(Object.values(components));
    const payrollStable = wages(c) === wages(next) && same(c.players.map(p=>[p.id,p.salary]),next.players.map(p=>[p.id,p.salary]));
    const facilitiesStable = oldInfo.facilities === newInfo.facilities;
    const residual = delta-expected;
    const beforeIds=new Set(c.players.map(p=>p.id));
    const addedPlayers=next.players.filter(p=>!beforeIds.has(p.id));
    // Audited source order only for these first three weeks: ensureAISheet precedes
    // billing; recruitment after billing is disabled at destination weeks 1/2/3.
    // Never extend this receipt to a trading window or interseason by inference.
    const sourceOrderVerified=before.season===1&&before.round>=0&&before.round<=2&&before.phase==='league'&&after.phase==='league'
      &&before.aiRosterVersion===1&&before.aiRoster?.version===1&&addedPlayers.length>0
      &&c.players.every(p=>next.players.some(q=>q.id===p.id&&q.salary===p.salary))
      &&addedPlayers.every(p=>after.aiRoster.events.some(e=>e.season===before.season&&e.clubId===c.id&&e.playerId===p.id
        &&['emergency','promote'].includes(e.kind)&&e.fee===0&&e.salary===p.salary));
    const residualAtClosingPayroll=delta-(expected-wages(next)+wages(c));
    const explained=sourceOrderVerified&&facilitiesStable&&residualAtClosingPayroll===0;
    return {clubId:c.id,kind:'ai',delta,components,expected,residual,payrollStable,facilitiesStable,
      payrollBefore:wages(c),payrollAfter:wages(next),payrollDelta:wages(next)-wages(c),
      addedPlayers:addedPlayers.map(p=>({id:p.id,weeklyWage:p.salary})),sourceOrderVerified,residualAtClosingPayroll,
      status:payrollStable&&facilitiesStable&&residual===0?'reconciled':explained?'reconciled-source-order':'unknown',
      ...(explained?{note:'Coverage additions precede billing; later recruitment disabled in audited first-three-week window.'}:
        payrollStable&&facilitiesStable&&residual===0?{}:{note:'Residual or payroll/facility change: no invented attribution to transfers, promotion, debt or investment.'})};
  });
  return {season:before.season,week:before.round,results:results.length,rows,
    ai:{clubs:rows.filter(r=>r.kind==='ai').length,reconciled:rows.filter(r=>r.status==='reconciled').length,
      explainedSourceOrder:rows.filter(r=>r.status==='reconciled-source-order').length,
      unknown:rows.filter(r=>r.kind==='ai'&&r.status==='unknown').length,
      delta:sum(rows.filter(r=>r.kind==='ai').map(r=>r.delta)),openingPayrollResidual:sum(rows.filter(r=>r.kind==='ai').map(r=>r.residual)),
      residual:sum(rows.filter(r=>r.kind==='ai').map(r=>r.status==='reconciled-source-order'?r.residualAtClosingPayroll:r.residual))}};
}
module.exports = {reconcile,upkeep,wages};
