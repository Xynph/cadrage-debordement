'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const E=require('../ci/economy-v2-e35-counterfactual.cjs');
test('E3.5 paired native facility action pays once and measures actual XP/rating separately',()=>{
 const r=E.facility(0,827381);
 assert.equal(r.sourceParity,true);assert.equal(r.matchResultDelta,null);
 assert.equal(r.leaguePositionDelta,null);assert.equal(r.seasonLongEffect,null);
 assert.equal(r.actualImmediateDebit,r.cashBefore-r.cashAfter);
 assert.equal(r.paidEventObserved,r.actionExecuted);
 assert.equal(r.eventDatePrecision,'season-only');
 assert(Number.isInteger(r.measuredGrowth.changedRating));
 assert(Number.isFinite(r.measuredGrowth.deltaXp));
});
test('E3.5 native academy choice 4000 is not a payable and measures real progress',()=>{
 const r=E.academy(0,827381,4000);
 assert.equal(r.sourceParity,true);assert.equal(r.actualImmediateDebit,r.cashBefore-r.cashAfter);
 assert([0,4000].includes(r.actualImmediateDebit));
 assert.equal(r.matchResultDelta,null);assert.equal(r.seasonLongEffect,null);
 assert.equal(r.measuredGrowth.observations.length,r.measuredGrowth.cohort);
});
test('E3.5 native academy choice 12000 on same seed measures, never guarantees',()=>{
 const r=E.academy(0,827381,12000);
 assert.equal(r.sourceParity,true);assert([0,12000].includes(r.actualImmediateDebit));
 assert.equal(r.matchResultDelta,null);assert.equal(r.leaguePositionDelta,null);
 assert.equal(r.growthInputRule,r.actualImmediateDebit?0.15:0);
});
test('E3.5 rejects mismatched cohorts rather than publishing invented progress',()=>{
 assert.throws(()=>E.comparePlayers([{id:'a',rating:50,xp:0}],[{id:'b',rating:51,xp:0.1}]));
});
