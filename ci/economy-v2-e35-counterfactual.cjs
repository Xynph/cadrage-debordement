'use strict';
// Isolated native experiments: both arms start from the same save + PRNG state.
const assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E33=require('./economy-v2-e33-investments.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function playerSample(g,academy=false){
 return N.data(g,academy?
  'S.development.academy.map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0,potential:p.dev?.potential??null}))':
  '([...club().players,...S.development.academy].filter(p=>p.age<=22&&!p.injury).map(p=>({id:p.id,rating:p.rating,xp:p.dev?.xp??0,potential:p.dev?.potential??null})))');
}
function comparePlayers(control,treated){
 const byId=new Map(control.map(p=>[p.id,p]));
 assert.equal(byId.size,control.length);
 assert.equal(treated.length,control.length);
 let deltaRating=0,deltaXp=0,changedRating=0,changedXp=0;
 const observations=[];
 for(const p of treated){
  const b=byId.get(p.id);assert(b,'Different player cohort in paired test');
  const dr=p.rating-b.rating,dx=p.xp-b.xp;
  assert(Number.isFinite(dr)&&Number.isFinite(dx));
  deltaRating+=dr;deltaXp+=dx;
  if(dr!==0)changedRating++;if(Math.abs(dx)>1e-10)changedXp++;
  observations.push({id:p.id,deltaRating:dr,deltaXp:dx});
 }
 return {cohort:control.length,deltaRating,deltaXp,changedRating,changedXp,
  positiveRatingCount:observations.filter(p=>p.deltaRating>0).length,
  // Counts are measurable, but XP changes cannot be interpreted as match performance.
  observations};
}
function sameOrigin(source){
 const a=N.capture(source);
 const control=N.fork(source),treated=N.fork(source);
 assert.deepEqual(N.data(control),a.document.state);
 assert.deepEqual(N.data(treated),a.document.state);
 assert.deepEqual(N.rng(control),a.rng);assert.deepEqual(N.rng(treated),a.rng);
 return {source,control,treated,original:a};
}
function finishPair(pair){
 const after=N.capture(pair.source);
 assert.deepEqual(after.document.state,pair.original.document.state,'Source save mutated');
 assert.equal(after.document.checksum,pair.original.document.checksum,'Source checksum mutated');
 assert.deepEqual(after.rng,pair.original.rng,'Source RNG mutated');
 return true;
}
function facility(clubId,seed){
 const source=N.fresh(clubId,seed);
 if(!source.run('worldActive()'))assert.equal(source.run('worldEnable()'),true);
 const pair=sameOrigin(source),{control,treated}=pair;
 const before=E33.observe(treated),q=before.facility?.quote;
 const can=!!(q?.affordableNow&&!before.facility.alreadyUpgraded&&before.phase==='league');
 const cashBefore=before.cash,ledgerBefore=N.data(treated,'S.ledger');
 const done=treated.run('worldUpgradeFacility()');
 assert.equal(done,can,'Native action availability diverges from quote');
 const after=E33.observe(treated);
 const debited=can?q.immediateCost:0;
 assert.equal(after.cash,cashBefore-debited,'Debit must be the actually executed quote');
 const entries=N.data(treated,'S.ledger');
 if(can){
  assert.equal(after.facility.level,before.facility.level+1);
  assert(entries.some(x=>x.title.includes('Investissement dans les installations')&&x.amount===-debited));
  assert(after.facility.paidEvents.some(x=>x.season===before.season&&x.cost===debited));
 }else assert.equal(after.facility.level,before.facility.level);
 assert.equal(entries.length-ledgerBefore.length,can?1:0,'Unexpected accounting entry');
 // Direct, native weekly training calls: controlled ONE-step microexperiment, NOT full season.
 const c0=playerSample(control),t0=playerSample(treated);
 assert.deepEqual(c0,t0);
 const handledControl=control.run('worldFacilityTraining()');
 const handledTreated=treated.run('worldFacilityTraining()');
 const growth=comparePlayers(playerSample(control),playerSample(treated));
 const r={kind:'facility',clubId,seed,season:before.season,round:before.round,
  actionExecuted:done,actualImmediateDebit:debited,cashBefore,cashAfter:after.cash,
  eventDatePrecision:'season-only',paidEventObserved:can,
  trainingCallsPerArm:1,handledControl,handledTreated,measuredGrowth:growth,
  matchResultDelta:null,leaguePositionDelta:null,seasonLongEffect:null,
  noHistoricalLiabilityCreated:true,sourceParity:finishPair(pair)};
 return r;
}
function academy(clubId,seed,choice=4000){
 assert([4000,12000].includes(choice));
 const source=N.fresh(clubId,seed);
 if(!source.run('careerIntegrated()'))assert.equal(source.run('careerEnable()'),true);
 const pair=sameOrigin(source),{control,treated}=pair;
 assert.equal(control.run('careerSetAcademyInvestment(0)'),true);
 assert.equal(treated.run('careerSetAcademyInvestment('+choice+')'),true);
 const before=E33.observe(treated),cashBefore=before.cash;
 const c0=playerSample(control,true),t0=playerSample(treated,true);
 assert.deepEqual(c0,t0);
 const controlExecuted=control.run('careerAcademyTraining()');
 const treatedExecuted=treated.run('careerAcademyTraining()');
 const after=E33.observe(treated);
 const paid=treatedExecuted&&cashBefore>=choice;
 assert.equal(after.cash,cashBefore-(paid?choice:0));
 assert.equal(after.academy.spentThisSeason-before.academy.spentThisSeason,paid?choice:0);
 const entries=N.data(treated,'S.ledger');
 if(paid)assert(entries.some(x=>x.title.includes('Investissement formation')&&x.amount===-choice));
 const growth=comparePlayers(playerSample(control,true),playerSample(treated,true));
 const r={kind:'academy',clubId,seed,season:before.season,round:before.round,
  choice,controlExecuted,treatedExecuted,actualImmediateDebit:paid?choice:0,
  cashBefore,cashAfter:after.cash,period:N.data(treated,'S.careerManagement.lastAcademyWeek'),
  growthInputRule:paid?(choice===4000?0.055:0.15):0,
  paidEventObserved:paid,trainingCallsPerArm:1,measuredGrowth:growth,
  matchResultDelta:null,leaguePositionDelta:null,seasonLongEffect:null,
  noHistoricalLiabilityCreated:true,sourceParity:finishPair(pair)};
 return r;
}
function run(clubId,seed){
 const f=facility(clubId,seed),a4=academy(clubId,seed,4000),a12=academy(clubId,seed,12000);
 return {stage:'E3.5',source:'native-paired-forks',clubId,seed,facility:f,
  academy4000:a4,academy12000:a12,
  limits:{fixtureExperiment:true,fullSeasonCausalEffect:null,
   matchResultsCompared:false,confirmedFutureLiability:null,guaranteedSportImprovement:null},
  saveParity:f.sourceParity&&a4.sourceParity&&a12.sourceParity,gameplayChanged:false};
}
module.exports={run,facility,academy,comparePlayers};
