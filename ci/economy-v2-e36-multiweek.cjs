'use strict';
// E3.6 research sandbox. Six deterministic weekly interventions, then actual native matches.
const assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E33=require('./economy-v2-e33-investments.cjs');
const WEEKS=6;
const sample=g=>N.data(g,'([...club().players,...S.development.academy].map(p=>({id:p.id,age:p.age,rating:p.rating,xp:p.dev?.xp??0,potential:p.dev?.potential??null})))');
function delta(baseline,control,treated){
 const a=new Map(baseline.map(p=>[p.id,p])),c=new Map(control.map(p=>[p.id,p])),t=new Map(treated.map(p=>[p.id,p]));
 const stable=[...a.keys()].filter(id=>c.has(id)&&t.has(id));
 let dr=0,dx=0,positiveRatings=0;
 for(const id of stable){
  const b=c.get(id),p=t.get(id),rating=p.rating-b.rating,xp=p.xp-b.xp;
  assert(Number.isFinite(rating)&&Number.isFinite(xp));
  dr+=rating;dx+=xp;if(rating>0)positiveRatings++;
 }
 return {originalCohort:a.size,stableCohort:stable.length,missingFromEither:a.size-stable.length,
  sumRatingDifference:dr,sumXpDifference:dx,positiveRatingPlayers:positiveRatings,
  source:'native-player-rating-and-dev-xp'};
}
const status=g=>N.data(g,'({season:S.season,round:S.round,phase:S.phase,week:S.economy.week,clubId:S.club,cash:club().cash,played:club().played,won:club().won,drawn:club().drawn,lost:club().lost,points:club().points,pf:club().pf,pa:club().pa})');
function origin(clubId,seed,kind){
 const src=N.fresh(clubId,seed);
 if(kind==='facility'&&!src.run('worldActive()'))assert.equal(src.run('worldEnable()'),true);
 if(kind==='academy'&&!src.run('careerIntegrated()'))assert.equal(src.run('careerEnable()'),true);
 const initial=N.capture(src),control=N.fork(src),treated=N.fork(src);
 assert.deepEqual(N.data(control),initial.document.state);
 assert.deepEqual(N.data(treated),initial.document.state);
 assert.deepEqual(N.rng(control),initial.rng);
 assert.deepEqual(N.rng(treated),initial.rng);
 return {src,initial,control,treated};
}
function run(clubId,seed,kind,level=0){
 assert(['facility','academy'].includes(kind));
 if(kind==='academy')assert([4000,12000].includes(level));
 const pair=origin(clubId,seed,kind),{control,treated}=pair;
 const before=sample(control),initial=status(control),rows=[];
 let directInvestment=0,paidSessions=0,facilityEvent=null;
 if(kind==='facility'){
  const e=E33.observe(treated),q=e.facility?.quote;
  const cash= status(treated).cash;
  const executed=treated.run('worldUpgradeFacility()');
  assert.equal(status(treated).cash,cash-(executed?q.immediateCost:0));
  if(executed){
   directInvestment=q.immediateCost;
   const event=E33.observe(treated).facility.paidEvents.find(x=>x.season===e.season&&x.cost===directInvestment);
   assert(event,'Missing executed native facilities event');
   facilityEvent={season:event.season,precision:'season-only',cost:event.cost,executed:true};
  }
 }else{
  assert.equal(control.run('careerSetAcademyInvestment(0)'),true);
  assert.equal(treated.run('careerSetAcademyInvestment('+level+')'),true);
 }
 let firstRngDivergence=null,firstScoreDivergence=null;
 for(let week=0;week<WEEKS;week++){
  const preC=status(control),preT=status(treated);
  assert.equal(preC.season,preT.season);assert.equal(preC.round,preT.round);
  const rngBeforeC=N.rng(control),rngBeforeT=N.rng(treated);
  if(!firstRngDivergence&&JSON.stringify(rngBeforeC)!==JSON.stringify(rngBeforeT))
   firstRngDivergence={week:week+1,stage:'before-training',control:rngBeforeC,treated:rngBeforeT};
  let paid=0,period=null,trainingC,trainingT;
  if(kind==='academy'){
   const cm=status(control).cash,tm=status(treated).cash;
   trainingC=control.run('careerAcademyTraining()');
   trainingT=treated.run('careerAcademyTraining()');
   const after=status(treated);
   paid=tm-after.cash;
   assert([0,level].includes(paid),'Unattested academy debit');
   assert.equal(status(control).cash,cm,'Zero-choice academy training charged cash');
   const evidence=E33.observe(treated).academy;
   period=evidence.lastPaidWeek;
   if(paid){assert.equal(paid,level);paidSessions++;directInvestment+=paid;}
   // Period is native season:economy.week; never a future invoice date.
  }else{
   trainingC=control.run('worldFacilityTraining()');
   trainingT=treated.run('worldFacilityTraining()');
  }
  const growth=delta(before,sample(control),sample(treated));
  const rngPreMatchC=N.rng(control),rngPreMatchT=N.rng(treated);
  const rngComparable=JSON.stringify(rngPreMatchC)===JSON.stringify(rngPreMatchT);
  if(!rngComparable&&!firstRngDivergence)
   firstRngDivergence={week:week+1,stage:'before-match',control:rngPreMatchC,treated:rngPreMatchT};
  // The true native fixture runs in both branches. Results after RNG divergence are descriptive ONLY.
  control.run('finishRound()');treated.run('finishRound()');
  const afterC=status(control),afterT=status(treated);
  assert.equal(afterC.round,afterT.round,'Paired match time diverged');
  assert.equal(afterC.season,afterT.season);
  const score={playedDifference:afterT.played-afterC.played,
   winsDifference:afterT.won-afterC.won,pointsDifference:afterT.points-afterC.points,
   scoredDifference:afterT.pf-afterC.pf,concededDifference:afterT.pa-afterC.pa};
  if(!firstScoreDivergence&&(score.winsDifference!==0||score.pointsDifference!==0||
      score.scoredDifference!==0||score.concededDifference!==0))
   firstScoreDivergence=week+1;
  const rngAfterC=N.rng(control),rngAfterT=N.rng(treated);
  if(!firstRngDivergence&&JSON.stringify(rngAfterC)!==JSON.stringify(rngAfterT))
   firstRngDivergence={week:week+1,stage:'after-match',control:rngAfterC,treated:rngAfterT};
  const controlDoc=N.data(control,'createSaveDocument()'),treatedDoc=N.data(treated,'createSaveDocument()');
  assert.equal(control.run('parseSaveDocument('+JSON.stringify(JSON.stringify(controlDoc))+').checksum'),controlDoc.checksum);
  assert.equal(treated.run('parseSaveDocument('+JSON.stringify(JSON.stringify(treatedDoc))+').checksum'),treatedDoc.checksum);
  rows.push({week:week+1,nativeSeason:preT.season,nativeRound:preT.round,
   nativeFinanceWeek:preT.week,trainingC,trainingT,paid,paidPeriod:period,
   cashControl:afterC.cash,cashTreated:afterT.cash,growth,
   nativeMatch:score,rngAlignedBeforeMatch:rngComparable,
   scoreInterpretation:rngComparable&&!firstRngDivergence?'paired-observation':'descriptive-after-rng-divergence',
   saveDocumentsValidated:true});
 }
 const after=N.capture(pair.src);
 assert.deepEqual(after.document.state,pair.initial.document.state,'Original save changed');
 assert.equal(after.document.checksum,pair.initial.document.checksum);
 assert.deepEqual(after.rng,pair.initial.rng,'Original RNG changed');
 const end=delta(before,sample(control),sample(treated));
 const report={kind,level,clubId,seed,weeks:WEEKS,initial,facilityEvent,
  actualInvestmentDebited:directInvestment,paidAcademySessions:paidSessions,
  rows,firstRngDivergence,firstScoreDivergence,endGrowth:end,
  observedFinalMatchDifference:rows.at(-1).nativeMatch,
  causalMatchImprovementGuaranteed:null,fullSeasonEffect:null,
  sourceSaveParity:true,gameplayChanged:false,createdHistoricalLiability:0};
 assert.equal(rows.length,WEEKS);return report;
}
module.exports={run,WEEKS};
