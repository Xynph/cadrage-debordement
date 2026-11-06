'use strict';
// E3.6 R&D: native four-week paired simulations, never imported by gameplay.
const assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E35=require('./economy-v2-e35-counterfactual.cjs');
const E33=require('./economy-v2-e33-investments.cjs');
const WEEKS=4;
function snapshot(g,kind){
 const people=N.data(g,kind==='facility'
  ?'([...club().players,...S.development.academy].filter(p=>p.age<=22&&!p.injury).map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0})))'
  :'S.development.academy.map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0}))');
 const state=N.data(g,'({season:S.season,round:S.round,phase:S.phase,week:S.economy.week,cash:club().cash,won:club().won,played:club().played,points:club().points,pf:club().pf,pa:club().pa,academySpent:S.careerManagement?.academySpent??null,academyWeeks:S.careerManagement?.academyWeeks??null,ledger:S.ledger.filter(e=>typeof e.title==="string"&&(e.title.includes("Investissement formation")||e.title.includes("Investissement dans les installations"))).map(e=>({title:e.title,amount:e.amount}))})');
 return {...state,people,rng:N.rng(g)};
}
function diffPeople(c,t){
 const cm=new Map(c.map(x=>[x.id,x])),tm=new Map(t.map(x=>[x.id,x]));
 const common=[...cm.keys()].filter(id=>tm.has(id));
 let rating=0,xp=0,ratingsChanged=0;
 for(const id of common){
  const a=cm.get(id),b=tm.get(id);
  rating+=b.rating-a.rating;xp+=b.xp-a.xp;
  if(b.rating!==a.rating)ratingsChanged++;
 }
 return {controlCount:c.length,treatedCount:t.length,matchedCount:common.length,
  ratingDelta:rating,xpDelta:xp,ratingsChanged,unmatchedCount:c.length+t.length-2*common.length,
  ratingDefinition:'sum of treated-minus-control observed player rating, matched IDs only',
  xpDefinition:'sum of fractional dev.xp differences, not cumulative XP granted'};
}
function experiment(clubId,seed,kind,choice=0){
 assert(['facility','academy'].includes(kind));
 assert(kind==='facility'||[4000,12000].includes(choice));
 const source=N.fresh(clubId,seed);
 if(!source.run('worldActive()'))assert.equal(source.run('worldEnable()'),true);
 if(!source.run('careerIntegrated()'))assert.equal(source.run('careerEnable()'),true);
 const before=N.capture(source),control=N.fork(source),treated=N.fork(source);
 assert.deepEqual(N.data(control),before.document.state);
 assert.deepEqual(N.data(treated),before.document.state);
 assert.deepEqual(N.rng(control),N.rng(treated));
 let facilityDebit=0,facilitySeason=null,facilityExecuted=false;
 if(kind==='facility'){
  const prior=E33.observe(treated),q=prior.facility?.quote;
  const cash=prior.cash;
  facilityExecuted=treated.run('worldUpgradeFacility()');
  const post=E33.observe(treated);
  const can=!!(q?.affordableNow&&!prior.facility.alreadyUpgraded&&prior.phase==='league');
  assert.equal(facilityExecuted,can);
  facilityDebit=facilityExecuted?q.immediateCost:0;
  assert.equal(post.cash,cash-facilityDebit);
  if(facilityExecuted){
   assert(post.facility.paidEvents.some(e=>e.season===prior.season&&e.cost===facilityDebit));
   facilitySeason=prior.season;
  }
 }else{
  assert.equal(control.run('careerSetAcademyInvestment(0)'),true);
  assert.equal(treated.run('careerSetAcademyInvestment('+choice+')'),true);
 }
 const records=[];let academyDebit=0,paidWeeks=0;
 for(let i=0;i<WEEKS;i++){
  const preC=snapshot(control,kind),preT=snapshot(treated,kind);
  assert.equal(preC.season,preT.season);
  assert.equal(preC.round,preT.round);
  assert.equal(preC.phase,'league');
  assert.equal(preT.phase,'league');
  const beforeCash=preT.cash;
  const previousSpent=preT.academySpent??0;
  control.run('trainWeek()');treated.run('trainWeek()');
  const afterTrain=snapshot(treated,kind);
  let paid=0;
  if(kind==='academy'){
   paid=(afterTrain.academySpent??0)-previousSpent;
   assert([0,choice].includes(paid),'Unexpected academy debit');
   academyDebit+=paid;if(paid)paidWeeks++;
   // Other training effects must not be silently treated as academy spending.
   assert.equal(afterTrain.cash-beforeCash,-paid,'Training cash delta unmatched');
  }
  control.run('finishRound()');treated.run('finishRound()');
  const c=snapshot(control,kind),t=snapshot(treated,kind);
  assert.equal(c.round,preC.round+1);assert.equal(t.round,preT.round+1);
  const rngAligned=N.rng(control).value===N.rng(treated).value
    &&N.rng(control).calls===N.rng(treated).calls;
  const match={control:{won:c.won,played:c.played,points:c.points,pf:c.pf,pa:c.pa},
    treated:{won:t.won,played:t.played,points:t.points,pf:t.pf,pa:t.pa},
    winsDifference:t.won-c.won,pointsDifference:t.points-c.points,
    pointsForDifference:t.pf-c.pf,pointsAgainstDifference:t.pa-c.pa,
    inference:rngAligned?'paired-seed-observation-not-proof-of-causality':'trajectory-diverged-no-causal-attribution'};
  records.push({weekIndex:i+1,season:preC.season,startingRound:preC.round,
    academyNativePeriod:preT.season+':'+preT.week,
    academyPaidThisWeek:paid,
    rng:{startAligned:preC.rng.value===preT.rng.value&&preC.rng.calls===preT.rng.calls,
      endAligned:rngAligned,controlCalls:c.rng.calls,treatedCalls:t.rng.calls},
    growth:diffPeople(c.people,t.people),match});
 }
 const finalC=snapshot(control,kind),finalT=snapshot(treated,kind);
 const finalGrowth=diffPeople(finalC.people,finalT.people);
 assert.equal(N.capture(source).document.checksum,before.document.checksum);
 assert.deepEqual(N.capture(source).document.state,before.document.state);
 assert.deepEqual(N.rng(source),before.rng);
 return {kind,choice:kind==='academy'?choice:null,clubId,seed,
  durationNativeRounds:WEEKS,records,facilityExecuted,facilityDebit,
  facilityEventDateSeason:facilitySeason,academyDebit,academyPaidWeeks:paidWeeks,
  totalPaidInvestment:facilityDebit+academyDebit,
  measuredFinalGrowth:finalGrowth,
  measuredMatchResult:{winsDifference:finalT.won-finalC.won,
    pointsDifference:finalT.points-finalC.points,
    pointsForDifference:finalT.pf-finalC.pf,
    pointsAgainstDifference:finalT.pa-finalC.pa,
    classification:'observed-paired-match-results-not-established-investment-causality'},
  firstRngDivergenceWeek:records.find(x=>!x.rng.endAligned)?.weekIndex??null,
  crossSeasonEffect:null,guaranteedSportOutcome:null,
  historicalDebtCreated:0,sourceSaveParity:true};
}
function run(clubId,seed){
 const facility=experiment(clubId,seed,'facility');
 const academy4000=experiment(clubId,seed,'academy',4000);
 const academy12000=experiment(clubId,seed,'academy',12000);
 return {stage:'E3.6',clubId,seed,facility,academy4000,academy12000,
  comparisons:3,roundsPerComparison:WEEKS,
  longTermCausalClaim:null,gameplayChanged:false,saveParity:true};
}
module.exports={experiment,run,diffPeople};
