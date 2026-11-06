'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs'),I=require('../ci/economy-v2-e33-investments.cjs');
test('E3.3 audit only preserves real native save and unknown promises',()=>{
 const g=N.fresh(0,827381),a=N.data(g,'createSaveDocument()'),x=I.observe(g),b=N.data(g,'createSaveDocument()');
 assert.deepEqual(a.state,b.state);assert.equal(a.checksum,b.checksum);
 assert.equal(x.readOnly,true);assert.equal(x.contract.accruedLiability,null);
 assert.equal(x.contract.futureScheduledInvestment,null);
 assert.equal(x.contract.confirmedFutureRevenue,null);
 assert.ok(x.facility===null||x.facility.quote===null||Number.isSafeInteger(x.facility.quote.immediateCost));
 assert.ok(x.academy===null||[0,4000,12000].includes(x.academy.selectedWeekly));
});
test('E3.3 optional native facility action on disposable fork, no invented investment',()=>{
 const original=N.fresh(0,827381),saved=N.data(original,'createSaveDocument()'),g=N.fork(original);
 if(!g.run('worldActive()'))assert.equal(g.run('worldEnable()'),true);
 const before=I.observe(g),quote=before.facility.quote;
 assert.ok(quote&&quote.immediateCost>=0);
 const can=quote.affordableNow&&!before.facility.alreadyUpgraded&&before.phase==='league';
 const ok=g.run('worldUpgradeFacility()');
 assert.equal(ok,can);
 const after=I.observe(g);
 if(can){
  assert.equal(after.cash-before.cash,-quote.immediateCost);
  assert.equal(after.facility.level,before.facility.level+1);
  assert.ok(after.facility.paidEvents.some(e=>e.season===before.season&&e.cost===quote.immediateCost));
  assert.ok(after.ledgerEvidence.some(e=>e.amount===-quote.immediateCost&&e.title.includes('Investissement dans les installations')));
 }else{assert.equal(after.cash,before.cash);}
 assert.deepEqual(N.data(original,'createSaveDocument()').state,saved.state);
});
test('E3.3 academy weekly selection is not an accrued payable; debit only on native training',()=>{
 const original=N.fresh(0,827381),saved=N.data(original,'createSaveDocument()'),g=N.fork(original);
 if(!g.run('careerIntegrated()'))assert.equal(g.run('careerEnable()'),true);
 const initial=I.observe(g);
 const eligible=initial.phase==='league'&&!g.run('Boolean(S.live)')&&!g.run('S.trained');
 if(!eligible)return;
 assert.equal(g.run('careerSetAcademyInvestment(4000)'),true);
 const selected=I.observe(g);
 assert.equal(selected.academy.selectedWeekly,4000);
 assert.equal(selected.contract.accruedLiability,null);
 assert.equal(selected.academy.spentThisSeason,initial.academy.spentThisSeason);
 const cashBefore=selected.cash;
 const executed=g.run('careerAcademyTraining()');
 const after=I.observe(g);
 if(cashBefore>=4000){
  assert.equal(executed,true);assert.equal(after.cash,cashBefore-4000);
  assert.equal(after.academy.spentThisSeason-selected.academy.spentThisSeason,4000);
  assert.ok(after.ledgerEvidence.some(e=>e.amount===-4000&&e.title.includes('Investissement formation')));
 }else{
  assert.equal(executed,false);assert.equal(after.cash,cashBefore);
 }
 assert.deepEqual(N.data(original,'createSaveDocument()').state,saved.state);
});
test('E3.3 contract rejects fictitious payable or unsupported academy levels',()=>{
 const x=I.observe(N.fresh(0,827381));
 assert.throws(()=>I.validate({...x,contract:{...x.contract,accruedLiability:0}}));
 if(x.academy)assert.throws(()=>I.validate({...x,academy:{...x.academy,selectedWeekly:9999}}));
});
