'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {run}=require('../ci/world-finance-flow-audit.cjs');
const {reconcile,upkeep}=require('../native/engine/world-finance-flow-audit.cjs');
test('A real worker week reconciles stable and source-order payrolls; isolated wage counterfactual preserves RNG and results',()=>{
  const r=run({seed:827381,weeks:1,club:0});
  assert.equal(r.passed,true);assert.equal(r.weeks[0].ai.clubs,57);
  assert.equal(r.weeks[0].ai.reconciled,54);assert.equal(r.weeks[0].ai.openingPayrollResidual,-8000);assert.equal(r.weeks[0].ai.residual,0);
  const explained=r.weeks[0].rows.filter(x=>x.kind==='ai'&&x.status==='reconciled-source-order');
  assert.deepEqual(explained.map(x=>x.clubId),[14,25,27]);assert.equal(r.weeks[0].ai.unknown,0);
  assert.equal(r.weeks[0].billingReplay.matched,57);
  for(const row of explained){assert.equal(row.payrollStable,false);assert.equal(row.residualAtClosingPayroll,0);assert.equal(row.residual,-row.payrollDelta);}
  assert.equal(r.weeks[0].rows.find(x=>x.kind==='human-ledger').status,'reconciled-ledger');
  assert.equal(r.counterfactual.cashDeltaDifference,-1000);assert(r.counterfactual.duplicateWeekRefused);
});
test('Coverage explanation cannot escape its source-order window, evidence or exact residual',()=>{
  const a={season:1,round:0,phase:'league',club:0,history:[],ledger:[],worldMode:{version:1},aiRosterVersion:1,aiRoster:{version:1,events:[]},
    worldManagement:{clubInfo:[{id:0,facilities:2},{id:1,facilities:2}]},clubs:[{id:0,cash:100,players:[]},{id:1,cash:100,players:[{id:'old',salary:1000}]}]};
  const b=structuredClone(a);b.round=1;b.clubs[1].players.push({id:'new',salary:2000});b.clubs[1].cash+=160000-3000;
  b.aiRoster.events.push({season:1,clubId:1,kind:'emergency',playerId:'new',salary:2000,fee:0});
  assert.equal(reconcile(a,b).rows[1].status,'reconciled-source-order');
  b.clubs[1].cash++;assert.equal(reconcile(a,b).rows[1].status,'unknown');b.clubs[1].cash--;
  b.aiRoster.events[0].fee=1;assert.equal(reconcile(a,b).rows[1].status,'unknown');b.aiRoster.events[0].fee=0;
  a.round=12;b.round=13;assert.equal(reconcile(a,b).rows[1].status,'unknown','trading week remains unknown');
});
test('Unexplained cash or payroll changes remain unknown, never attributed to a made-up flow',()=>{
  const a={season:1,round:0,club:0,history:[],ledger:[],worldMode:{version:1},worldManagement:{clubInfo:[{id:0,facilities:2},{id:1,facilities:3}]},clubs:[{id:0,cash:100,players:[{id:'a',salary:1}]},{id:1,cash:100,players:[{id:'b',salary:2000}]}]};
  const b=structuredClone(a);b.round=1;b.clubs[1].cash+=160000-2000-upkeep(3)+999;
  const row=reconcile(a,b).rows[1];assert.equal(row.residual,999);assert.equal(row.status,'unknown');
  b.clubs[1].cash-=999;b.clubs[1].players[0].salary++;
  assert.equal(reconcile(a,b).rows[1].status,'unknown');
  b.season++;assert.throws(()=>reconcile(a,b),/no interseason/);
});
