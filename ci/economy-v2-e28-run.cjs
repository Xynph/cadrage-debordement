'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E27=require('./economy-v2-durable-run.cjs');
function run(profile,seed){
 const observed=E27.run(profile,seed);
 assert.equal(observed.seasons,15);
 assert.equal(observed.rounds,435);
 assert.equal(observed.rollovers,14);
 assert.equal(observed.imports,3);
 assert.equal(observed.legacySaveUnchanged,true);
 assert.equal(observed.nativeObligationsCreated,0);
 assert.equal(observed.durableFixturePayments,1);
 assert.equal(observed.crashRecovery,true);
 assert.equal(observed.atomicReplay,true);
 assert.equal(observed.signedProofVerified,true);
 return {schema:1,stage:'E2.8',profile,seed,source:'native-game-and-separate-durable-fixture',
  seasons:observed.seasons,rounds:observed.rounds,rollovers:observed.rollovers,
  imports:observed.imports,nativeCashMovements:observed.nativeCashMovements,
  legacySaveUnchanged:observed.legacySaveUnchanged,saveChecksum:observed.originalChecksum,
  historicalPayablesImported:0,unknownLegacyLiabilities:observed.nativeLegacyLiabilitiesUnknown,
  fixtureReplayedWithoutDoublePay:observed.atomicReplay,
  fixtureCrashRecovered:observed.crashRecovery,fixtureProofValid:observed.signedProofVerified,
  qualification:'SIGKILL and multiprocess concurrency are separately covered by E2.8 Node tests'};
}
if(require.main===module){try{
 const [profile,seed,out='economy-v2-e28-reports']=process.argv.slice(2);
 const data=run(profile,Number(seed));fs.mkdirSync(out,{recursive:true});
 fs.writeFileSync(path.join(out,'e28-'+profile+'-'+seed+'.json'),JSON.stringify(data,null,2));
 console.log('E28 PASS '+JSON.stringify(data));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
