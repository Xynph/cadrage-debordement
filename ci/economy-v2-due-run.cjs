'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E24=require('./economy-v2-obligations-run.cjs');
const Due=require('../dist/economy-v2-due-contract.js');
function run(profile,seed){
 const actual=E24.run(profile,seed);
 assert.equal(actual.series.length,15);assert.equal(actual.counts.rounds,435);
 assert.equal(actual.counts.imports,3);assert.equal(actual.counts.rollovers,14);
 assert.equal(actual.counts.unmeasuredLiabilities,14*15);
 // Separate native legacy save proof. No obligations are inferred from the live club data.
 const g=N.fresh(({reference:0,modeste:13,alternatif:6})[profile],seed);
 const save=N.data(g,'createSaveDocument()'),original=JSON.stringify(save);
 const preview=Due.legacyPreview(save.state);
 assert.equal(Due.validate(preview.ledger),true);
 assert.equal(preview.legacyUnmeasuredLiabilities,null);
 assert.equal(preview.ledger.obligations.length,0);
 assert.equal(JSON.stringify(save),original);
 const after=N.data(g,'createSaveDocument()');
 assert.equal(after.checksum,save.checksum);assert.deepEqual(after.state,save.state);
 // Deterministic, explicit evidence stress separate from natural career.
 let stress=Due.create();
 stress=Due.register(stress,{clubId:'club-test',obligationId:'explicit-invoice',
  amount:350000,due:'2028-03',confirmedPeriod:'2028-01',
  evidenceKind:'invoice-approved',evidenceRef:'real-proof-fixture'});
 stress=Due.mature(stress,'2028-03');
 assert.equal(Due.summary(stress,'club-test','2028-03').dueUnpaid,350000);
 const output={schema:1,profile,seed,source:'native-game-actual',native:{
   seasons:actual.series.length,rounds:actual.counts.rounds,rollovers:actual.counts.rollovers,
   imports:actual.counts.imports,cashMovements:actual.counts.cashMovements,
   legacyLiabilitiesUnknown:actual.counts.unmeasuredLiabilities,
   contractualEvidenceCreated:preview.contractualEvidenceCreated},
   stress:{due:Due.summary(stress,'club-test','2028-03').dueUnpaid,
    paid:stress.payments.length,syntheticFixture:true},saveChecksum:save.checksum,
   limitation:'No financial obligations imported from native legacy; unknown is null'};
 return output;
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e25-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'due-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E25 PASS '+JSON.stringify(r));
}catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
