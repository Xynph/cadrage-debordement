'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const E=require('../ci/economy-v2-e36-multiweek.cjs');
test('E3.6 four native weeks compare real training and match records',()=>{
 const x=E.experiment(0,827381,'facility');
 assert.equal(x.durationNativeRounds,4);assert.equal(x.records.length,4);
 assert.equal(x.sourceSaveParity,true);
 assert.equal(x.historicalDebtCreated,0);
 assert.equal(x.facilityDebit,x.facilityExecuted?750000:0);
 for(const row of x.records){
  assert.equal(typeof row.match.winsDifference,'number');
  assert.equal(typeof row.match.pointsDifference,'number');
  assert.equal(typeof row.rng.endAligned,'boolean');
  assert.equal(typeof row.growth.ratingDelta,'number');
 }
 assert.equal(x.crossSeasonEffect,null);assert.equal(x.guaranteedSportOutcome,null);
});
test('E3.6 academy 4000 payments must arise from native weekly training',()=>{
 const x=E.experiment(0,827381,'academy',4000);
 assert.equal(x.sourceSaveParity,true);
 assert.equal(x.records.length,4);
 assert.equal(x.academyDebit,x.records.reduce((n,w)=>n+w.academyPaidThisWeek,0));
 assert(x.records.every(x=>[0,4000].includes(x.academyPaidThisWeek)));
 assert.equal(x.historicalDebtCreated,0);
});
test('E3.6 academy 12000 preserves debits, sports observation and unknown causality',()=>{
 const x=E.experiment(0,827381,'academy',12000);
 assert.equal(x.records.length,4);assert.equal(x.sourceSaveParity,true);
 assert(x.records.every(x=>[0,12000].includes(x.academyPaidThisWeek)));
 assert.equal(x.measuredMatchResult.classification,'observed-paired-match-results-not-established-investment-causality');
 assert.equal(x.guaranteedSportOutcome,null);
});
test('E3.6 cohort matching rejects pretending a changed cohort is fixed',()=>{
 const a=E.diffPeople([{id:'a',rating:50,xp:.2}],[{id:'b',rating:54,xp:.5}]);
 assert.equal(a.matchedCount,0);assert.equal(a.unmatchedCount,2);
 assert.equal(a.ratingDelta,0);
});
