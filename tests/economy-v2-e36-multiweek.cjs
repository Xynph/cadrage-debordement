'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const R=require('../ci/economy-v2-e36-multiweek.cjs');
for(const [kind,level] of [['facility',0],['academy',4000],['academy',12000]]){
 test('E3.6 native six weeks '+kind+' '+level+' on controlled paired clones',()=>{
  const r=R.run(0,827381,kind,level);
  assert.equal(r.rows.length,6);
  assert.equal(r.sourceSaveParity,true);
  assert.equal(r.gameplayChanged,false);
  assert.equal(r.createdHistoricalLiability,0);
  assert.equal(r.causalMatchImprovementGuaranteed,null);
  assert.equal(r.fullSeasonEffect,null);
  assert.equal(r.endGrowth.source,'native-player-rating-and-dev-xp');
  assert(r.rows.every(x=>x.saveDocumentsValidated&&x.week>=1&&x.week<=6));
  assert(r.rows.every(x=>Number.isFinite(x.growth.sumXpDifference)&&
   Number.isFinite(x.growth.sumRatingDifference)));
  assert(r.rows.every(x=>x.nativeMatch&&Number.isFinite(x.nativeMatch.pointsDifference)));
  if(kind==='facility'){
   assert.equal(r.paidAcademySessions,0);
   if(r.facilityEvent)assert.equal(r.actualInvestmentDebited,r.facilityEvent.cost);
  }else{
   assert([0,level*6].includes(r.actualInvestmentDebited)||r.actualInvestmentDebited%level===0);
   assert.equal(r.actualInvestmentDebited,r.rows.reduce((sum,x)=>sum+x.paid,0));
   assert(r.rows.every(x=>[0,level].includes(x.paid)));
  }
 });
}
test('E3.6 does not publish causal victory claims when RNG branches diverge',()=>{
 const r=R.run(0,99173,'academy',12000);
 assert.equal(r.causalMatchImprovementGuaranteed,null);
 assert(r.rows.every(x=>['paired-observation','descriptive-after-rng-divergence'].includes(x.scoreInterpretation)));
 if(r.firstRngDivergence)assert(r.rows.some(x=>x.scoreInterpretation==='descriptive-after-rng-divergence'));
});
