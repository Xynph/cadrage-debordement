'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const Previous=require('./economy-v2-atomic-run.cjs'),E1=require('../dist/economy-v2-core.js'),Store=require('./economy-v2-durable-store.cjs');
function run(profile,seed){
 const native=Previous.run(profile,seed);
 assert.equal(native.seasons,15);assert.equal(native.imports,3);assert.equal(native.legacySaveUnchanged,true);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e27-matrix-')),file=path.join(dir,'accounting.json');
 try{
  const key=Buffer.alloc(32,seed%200+10);
  const bill={clubId:'sandbox',obligationId:'verified-invoice',amount:350000,due:'2028-03',
   confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'trusted-fixture'};
  const receipt={clubId:'sandbox',obligationId:'verified-invoice',paymentId:'bank-event',
   paidPeriod:'2028-03',receiptRef:'verified-bank-fixture'};
  Store.initialize(file,['sandbox']);
  Store.transact(file,s=>({...s,ledger:E1.injectCapital(s.ledger,{clubId:'sandbox',eventId:'sandbox-capital',period:'2027-01',amount:1000000})}));
  Store.register(file,bill,Store.sealFixture(key,'obligation',bill),key);
  Store.mature(file,'2028-03');
  try{Store.settle(file,receipt,Store.sealFixture(key,'receipt',receipt),key,{failpoint:'after-rename'});throw Error('Crash injection missing')}
  catch(e){assert.match(e.message,/Simulated crash after rename/)}
  const prior=Store.read(file);
  Store.settle(file,receipt,Store.sealFixture(key,'receipt',receipt),key);
  const after=Store.read(file);
  assert.equal(after.revision,prior.revision);
  assert.equal(after.state.ledger.balances.sandbox.cash,650000);
  assert.equal(after.state.due.payments.length,1);
  return {schema:1,profile,seed,source:'native-career-and-independent-durable-fixture',
    seasons:native.seasons,rounds:native.rounds,rollovers:native.rollovers,imports:native.imports,
    nativeCashMovements:native.nativeCashMovements,
    nativeLegacyLiabilitiesUnknown:native.nativeLegacyLiabilitiesUnknown,
    legacySaveUnchanged:native.legacySaveUnchanged,originalChecksum:native.checksum,
    nativeObligationsCreated:0,durableFixtureObligations:1,durableFixturePayments:1,
    durableCashAfter:after.state.ledger.balances.sandbox.cash,
    signedProofVerified:true,crashRecovery:true,atomicReplay:true};
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
}
if(require.main===module){try{
 const [profile,seed,out='economy-v2-e27-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'durable-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E27 PASS '+JSON.stringify(r));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
