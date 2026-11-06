'use strict';
// E3.7 standalone R&D on disposable native saves; no gameplay import.
const assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E33=require('./economy-v2-e33-investments.cjs');
const E36=require('./economy-v2-e36-multiweek.cjs');
const KINDS=['facility','academy4000','academy12000'];
function sample(g,kind){
 const players=N.data(g,kind==='facility'?
  '([...club().players,...S.development.academy].filter(p=>p.age<=22).map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0})))':
  'S.development.academy.map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0}))');
 const state=N.data(g,`({season:S.season,round:S.round,phase:S.phase,week:S.economy.week,
  cash:club().cash,won:club().won,played:club().played,points:club().points,
  pf:club().pf,pa:club().pa,academySpent:S.careerManagement.academySpent,
  academyWeeks:S.careerManagement.academyWeeks,
  facilities:worldClub(S.club).facilities,
  facilityUpgrades:S.worldManagement.upgrades.filter(e=>e.id===S.club).map(e=>({season:e.season,cost:e.cost,level:e.level})),
  leagueRank:ranked().findIndex(c=>c.id===S.club)+1,
  ownLast:S.history.filter(r=>r.pair.includes(S.club)).at(-1)?
    (()=>{const r=S.history.filter(r=>r.pair.includes(S.club)).at(-1);
      const index=r.pair.indexOf(S.club);
      return {season:S.season,round:r.round,phase:r.phase,
        scored:r.score[index],conceded:r.score[1-index],won:r.score[index]>r.score[1-index]};})():null,
  lastFacilityUpkeep:S.ledger.find(e=>typeof e.title==='string'&&e.title.includes('Entretien des installations'))?.amount??null})`);
 return {...state,players,rng:N.rng(g)};
}
function experiment(clubId,seed,kind){
 assert(KINDS.includes(kind));
 const source=N.fresh(clubId,seed);
 if(!source.run('worldActive()'))assert.equal(source.run('worldEnable()'),true);
 if(!source.run('careerIntegrated()'))assert.equal(source.run('careerEnable()'),true);
 const origin=N.capture(source),control=N.fork(source),treated=N.fork(source);
 assert.deepEqual(N.data(control),N.data(treated));
 assert.deepEqual(N.rng(control),N.rng(treated));
 let facilityDebit=0,facilityEvent=null;
 if(kind==='facility'){
  const before=E33.observe(treated);
  const accepted=treated.run('worldUpgradeFacility()');
  const after=E33.observe(treated);
  assert.equal(accepted,!!(before.facility.quote?.affordableNow&&!before.facility.alreadyUpgraded&&before.phase==='league'));
  facilityDebit=accepted?before.facility.quote.immediateCost:0;
  assert.equal(after.cash,before.cash-facilityDebit);
  if(accepted){
   facilityEvent=after.facility.paidEvents.find(e=>e.season===before.season&&e.cost===facilityDebit);
   assert(facilityEvent,'No native facility event after debit');
  }
 }else{
  const amount=kind==='academy4000'?4000:12000;
  assert.equal(control.run('careerSetAcademyInvestment(0)'),true);
  assert.equal(treated.run('careerSetAcademyInvestment('+amount+')'),true);
 }
 let academyDebit=0,academyPaidPeriods=[],facilityUpkeepDelta=0,upkeepCompared=0;
 const steps=[],matchPairs=[],maxRounds=29;
 for(let index=0;index<maxRounds;index++){
  const preC=sample(control,kind),preT=sample(treated,kind);
  assert.equal(preC.season,preT.season);
  assert.equal(preC.phase,preT.phase,'Competition phases have diverged; stop before mismatched schedule');
  assert.equal(preC.round,preT.round);
  assert.notEqual(preC.phase,'ended','Season ended before scheduled round count');
  const cashBefore=preT.cash,academyBefore=preT.academySpent;
  control.run('trainWeek()');treated.run('trainWeek()');
  const trained=sample(treated,kind);
  const paid=trained.academySpent-academyBefore;
  assert(Number.isSafeInteger(paid)&&paid>=0);
  if(kind==='facility')assert.equal(paid,0);
  else assert([0,kind==='academy4000'?4000:12000].includes(paid));
  assert.equal(trained.cash-cashBefore,-paid,'Native weekly training debit not reconciled');
  if(paid){academyDebit+=paid;academyPaidPeriods.push({season:preT.season,economyWeek:preT.week,round:preT.round,paid});}
  control.run('finishRound()');treated.run('finishRound()');
  const c=sample(control,kind),t=sample(treated,kind);
  assert.equal(c.phase,t.phase,'Competition outcome changed phase; require explicit divergence classification');
  assert.equal(c.round,t.round);
  const rngAligned=c.rng.calls===t.rng.calls&&c.rng.value===t.rng.value;
  const growth=E36.diffPeople(c.players,t.players);
  const ctrlMatch=c.ownLast?.round===preC.round&&c.ownLast?.phase===preC.phase?c.ownLast:null;
  const trtMatch=t.ownLast?.round===preT.round&&t.ownLast?.phase===preT.phase?t.ownLast:null;
  assert.equal(!!ctrlMatch,!!trtMatch,'Manager club participation diverged');
  if(ctrlMatch)matchPairs.push({round:index+1,phase:preC.phase,
    control:{scored:ctrlMatch.scored,conceded:ctrlMatch.conceded,won:ctrlMatch.won},
    treated:{scored:trtMatch.scored,conceded:trtMatch.conceded,won:trtMatch.won},
    rngAligned,scoreDelta:trtMatch.scored-ctrlMatch.scored,
    concededDelta:trtMatch.conceded-ctrlMatch.conceded});
  if(c.lastFacilityUpkeep!==null&&t.lastFacilityUpkeep!==null){
   facilityUpkeepDelta+=c.lastFacilityUpkeep-t.lastFacilityUpkeep;
   upkeepCompared++;
  }
  steps.push({round:index+1,phase:preC.phase,season:preC.season,academyPaid:paid,
    cashGap:t.cash-c.cash,upkeepIncrementPaid:facilityUpkeepDelta,
    growth:{ratingDelta:growth.ratingDelta,xpResidualDelta:growth.xpDelta,matched:growth.matchedCount,unmatched:growth.unmatchedCount},
    rng:{aligned:rngAligned,controlCalls:c.rng.calls,treatedCalls:t.rng.calls},
    matchesObserved:matchPairs.length});
 }
 const c=sample(control,kind),t=sample(treated,kind);
 assert.equal(c.phase,'ended');assert.equal(t.phase,'ended');
 assert.equal(steps.length,maxRounds);
 const g=E36.diffPeople(c.players,t.players);
 assert.deepEqual(N.capture(source),origin,'Original native save or RNG changed');
 const checkedC=N.capture(control),checkedT=N.capture(treated);
 assert.equal(N.restore(checkedC.document,checkedC.rng).run('S.phase'),'ended');
 assert.equal(N.restore(checkedT.document,checkedT.rng).run('S.phase'),'ended');
 const leagueMatches=matchPairs.filter(x=>x.phase==='league');
 assert.equal(leagueMatches.length,26,'Expected all 26 native league fixtures for managed club');
 const firstRngDivergence=steps.find(s=>!s.rng.aligned)?.round??null;
 return {kind,clubId,seed,season:origin.document.state.season,
  rounds:maxRounds,leagueMatches:leagueMatches.length,
  matchPairs,progressCheckpoints:steps,facilityDebit,
  facilityEvent:facilityEvent?{season:facilityEvent.season,level:facilityEvent.level,cost:facilityEvent.cost,datePrecision:'season-only'}:null,
  academyDebit,academyPaidPeriods,upkeepCompared,incrementalFacilityUpkeepPaid:facilityUpkeepDelta,
  accounting:{observedInvestmentAndUpkeepPaid:facilityDebit+academyDebit+Math.max(0,facilityUpkeepDelta),
   endCashGap:t.cash-c.cash,cashGapIncludesOtherNativeTransactions:true,
   futureDebt:null,forecastIncome:null,unpaidWeeklyChoicesAreDebts:false},
  finalGrowth:g,finalLeagueRank:{control:c.leagueRank,treated:t.leagueRank},
  observedLeague:{winsDelta:t.won-c.won,pointsDelta:t.points-c.points,pfDelta:t.pf-c.pf,paDelta:t.pa-c.pa},
  firstRngDivergence,scoreDifferences:matchPairs.filter(x=>x.scoreDelta!==0||x.concededDelta!==0).length,
  causalSportEffect:null,guaranteedWins:null,otherSeasonsEffect:null,
  savesRoundTrip:true,originalSaveAndRngParity:true,gameplayChanged:false};
}
function run(clubId,seed){
 const x=KINDS.map(kind=>experiment(clubId,seed,kind));
 return {stage:'E3.7',clubId,seed,facility:x[0],academy4000:x[1],academy12000:x[2],
  pairedFullSeasons:3,pairedSeasonRounds:29,causalSportEffect:null,gameplayChanged:false};
}
module.exports={experiment,run,sample};
