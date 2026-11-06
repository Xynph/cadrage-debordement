'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const E=require('../ci/economy-v2-e37-season.cjs');
function check(x){
 assert.equal(x.rounds,29);assert.equal(x.leagueMatches,26);
 assert.equal(x.matchPairs.filter(m=>m.phase==='league').length,26);
 assert.equal(x.savesRoundTrip,true);assert.equal(x.originalSaveAndRngParity,true);
 assert.equal(x.accounting.futureDebt,null);assert.equal(x.causalSportEffect,null);
 assert.equal(x.guaranteedWins,null);assert.equal(x.gameplayChanged,false);
 assert(x.progressCheckpoints.every(r=>Number.isFinite(r.cashGap)&&typeof r.rng.aligned==='boolean'));
}
test('E3.7 actual facility debit and upkeep on complete native paired season',()=>{
 const r=E.experiment(0,827381,'facility');check(r);
 assert([0,750000].includes(r.facilityDebit));
 if(r.facilityDebit)assert.equal(r.facilityEvent.cost,r.facilityDebit);
 assert.equal(r.academyDebit,0);
 assert(r.upkeepCompared>=26);
 assert.equal(typeof r.observedLeague.winsDelta,'number');
});
test('E3.7 native 4000 academy actually debits paid weeks, no phantom payables',()=>{
 const r=E.experiment(0,827381,'academy4000');check(r);
 assert.equal(r.facilityDebit,0);
 assert.equal(r.academyDebit,r.academyPaidPeriods.reduce((a,e)=>a+e.paid,0));
 assert(r.academyPaidPeriods.every(e=>e.paid===4000));
 assert.equal(r.accounting.unpaidWeeklyChoicesAreDebts,false);
});
test('E3.7 native 12000 academy notes, scores and RNG divergence remain evidence',()=>{
 const r=E.experiment(0,827381,'academy12000');check(r);
 assert.equal(r.facilityDebit,0);
 assert(r.academyPaidPeriods.every(e=>e.paid===12000));
 assert.equal(r.academyDebit,r.academyPaidPeriods.reduce((a,e)=>a+e.paid,0));
 assert.equal(r.finalGrowth.ratingDelta,Math.trunc(r.finalGrowth.ratingDelta));
 assert(r.firstRngDivergence===null||r.firstRngDivergence>=1);
 assert.equal(typeof r.finalLeagueRank.control,'number');
});
