'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs');
const E33=require('../ci/economy-v2-e33-investments.cjs');
const E34=require('../ci/economy-v2-e34-advisor.cjs');
test('E3.4 decisions are derived from native snapshot without changing saves',()=>{
 const g=N.fresh(0,827381),before=N.data(g,'createSaveDocument()');
 const snapshot=E33.observe(g),a=E34.build(snapshot),after=N.data(g,'createSaveDocument()');
 assert.deepEqual(after.state,before.state);assert.equal(after.checksum,before.checksum);
 assert.equal(a.gameplayChanged,false);assert.equal(a.unknown.dueLiability,null);
 assert.equal(a.unknown.futureSportResult,null);
 if(snapshot.facility){
  assert.equal(a.facility.canExecuteNow,!!(snapshot.facility.quote&&snapshot.facility.quote.affordableNow&&!snapshot.facility.alreadyUpgraded&&snapshot.phase==='league'));
  assert.equal(a.facility.quoteImmediate,snapshot.facility.quote?.immediateCost??null);
 }
 if(snapshot.academy)for(const item of a.academy.conditionalNextSessionOptions)
  assert.equal(item.cashSufficiencyAtSnapshot,snapshot.cash>=item.choice);
});
test('E3.4 refuses fake debt, fake results and fabricated debit',()=>{
 const a=E34.build(E33.observe(N.fresh(0,827381)));
 assert.throws(()=>E34.validate({...a,unknown:{...a.unknown,dueLiability:0}}));
 assert.throws(()=>E34.validate({...a,unknown:{...a.unknown,futureSportResult:1}}));
 assert.throws(()=>E34.validate({...a,comparison:{...a.comparison,academyTrainingExecuted:true}}));
});
test('E3.4 historical records are not comprehensive future payment schedules',()=>{
 const x=E34.build(E33.observe(N.fresh(13,99173)));
 assert.equal(x.unknown.futureExpenseSchedule,null);
 if(x.facility)assert(x.facility.historicalPaidEvents.every(v=>v.datePrecision==='season-only'));
 if(x.academy)assert(x.academy.conditionalNextSessionOptions.every(v=>v.scheduledDebt===null));
});
