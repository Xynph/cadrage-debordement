'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E29=require('./economy-v2-e29-run.cjs');
const P=require('./economy-v2-e30-playability.cjs');
const cases={
 temporaryRevenueDip:{
  openingCash:100,income:[10,10,40,45,45,45],required:[20,20,20,20,20,20],
  optional:[35,0,0,0,0,0],targetReserve:30
 },
 optionalInvestmentOverreach:{
  openingCash:70,income:[25,25,25,25,25,25],required:[20,20,20,20,20,20],
  optional:[70,25,20,0,0,0],targetReserve:35
 },
 mandatoryCostsUncovered:{
  openingCash:20,income:[5,5,5,5,5,5],required:[40,40,40,40,40,40],
  optional:[0,0,0,0,0,0],targetReserve:0
 },
 laterEarnedIncome:{
  openingCash:20,income:[10,10,65,65,65,65],required:[25,25,25,25,25,25],
  optional:[30,0,0,0,0,0],targetReserve:15
 }
};
function run(profile,seed){
 const observed=E29.run(profile,seed);
 assert.equal(observed.seasons,15);assert.equal(observed.imports,3);
 assert.equal(observed.legacySaveUnchanged,true);assert.equal(observed.nativePayablesCreated,0);
 assert.equal(observed.anchorFixture.restoredSnapshotRejected,true);
 const checks=Object.fromEntries(Object.entries(cases).map(([name,input])=>[name,P.compare(input)]));
 // A crisis must be genuinely reversible through optional choices or new earnings already listed,
 // not by moving a mandatory obligation into a fabricated payable.
 assert.equal(checks.temporaryRevenueDip.options[0].endingCash,140);
 assert.ok(checks.optionalInvestmentOverreach.options[2].endingCash>=checks.optionalInvestmentOverreach.options[0].endingCash);
 assert.equal(checks.mandatoryCostsUncovered.summary.recoveryPossibleWithoutNewMoney,false);
 assert.ok(checks.laterEarnedIncome.options[2].endingCash>0);
 assert.equal(checks.laterEarnedIncome.summary.recoveryPossibleWithoutNewMoney,true);
 for(const c of Object.values(checks)){
  assert.equal(c.options.length,3);
  for(const o of c.options){
   assert.equal(o.generatedIncome,0);assert.equal(o.generatedLoans,0);
   assert.equal(o.createdDebt,0);assert.equal(o.addedPenalties,0);
   assert.ok(o.weekly.every(x=>x.mandatoryPaid>=0));
  }
 }
 return {schema:1,stage:'E3.0',profile,seed,source:'native-fifteen-seasons-plus-explicit-synthetic-choice-fixtures',
  native:{seasons:observed.seasons,rounds:observed.rounds,rollovers:observed.rollovers,
   imports:observed.imports,cashMovements:observed.cashMovements,saveParity:observed.legacySaveUnchanged,
   saveChecksum:observed.saveChecksum,legacyPayablesCreated:observed.nativePayablesCreated,
   indicativePressure:observed.playableObservation.totalPressureObservations,
   indicativeRecovery:observed.playableObservation.observedRecoveryTransitions,
   minObservedClubCash:observed.playableObservation.minClubCash},
  illustrativeScenarios:checks,
  gameplayChanged:false,trustRootLimitation:'Local HMAC witness is not a truly separate monotonic authority',
  qualification:'Forecast and fixture results are not the native game economy or player UX proof'};
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e30-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'e30-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E30 PASS '+JSON.stringify({profile,seed,native:r.native,
  scenarioOutcomes:Object.fromEntries(Object.entries(r.illustrativeScenarios).map(([k,v])=>[k,{
   endings:v.options.map(o=>o.endingCash),optionalDeferred:v.options.map(o=>o.optionalDeferred),
   recoveryWithoutNewMoney:v.summary.recoveryPossibleWithoutNewMoney
  }]))}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
