'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const Native=require('../tests/career-resilience/native.cjs');
const E24=require('./economy-v2-obligations-run.cjs');
const E1=require('../dist/economy-v2-core.js');
const A=require('../dist/economy-v2-atomic-adapter.js');
function run(profile,seed){
 const observed=E24.run(profile,seed);
 assert.equal(observed.series.length,15);assert.equal(observed.counts.rounds,435);
 assert.equal(observed.counts.rollovers,14);assert.equal(observed.counts.imports,3);
 const g=Native.fresh(({reference:0,modeste:13,alternatif:6})[profile],seed);
 const before=Native.data(g,'createSaveDocument()'),beforeState=JSON.stringify(before.state);
 const trusted=(kind,doc)=>kind==='obligation'?doc.evidenceRef==='explicit-fixture':
   kind==='receipt'?doc.receiptRef==='explicit-bank-fixture':false;
 let x=A.create(['sandbox']);
 x={...x,ledger:E1.injectCapital(x.ledger,{clubId:'sandbox',eventId:'sandbox-capital',period:'2027-01',amount:1000000})};
 const bill={clubId:'sandbox',obligationId:'invoice',amount:350000,due:'2028-03',
  confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'explicit-fixture'};
 const receipt={clubId:'sandbox',obligationId:'invoice',paymentId:'bank-event',
  paidPeriod:'2028-03',receiptRef:'explicit-bank-fixture'};
 x=A.mature(A.register(x,bill,trusted),'2028-03');
 const settled=A.settle(x,receipt,trusted),again=A.settle(A.restore(JSON.stringify(settled)),receipt,trusted);
 assert.equal(E1.snapshot(again.ledger,'sandbox').cash,650000);
 assert.equal(again.due.payments.length,1);
 assert.throws(()=>A.settle(again,{...receipt,paymentId:'other'},trusted));
 const after=Native.data(g,'createSaveDocument()');
 assert.equal(beforeState,JSON.stringify(after.state));
 assert.equal(before.checksum,after.checksum);
 return {profile,seed,source:'actual-native-career-with-isolated-payment-fixture',seasons:15,
  rounds:observed.counts.rounds,rollovers:observed.counts.rollovers,imports:observed.counts.imports,
  nativeCashMovements:observed.counts.cashMovements,nativeLegacyLiabilitiesUnknown:observed.counts.unmeasuredLiabilities,
  createdNativeObligations:0,isolatedVerifiedObligations:1,isolatedPayments:1,
  isolatedCashPaid:350000,isolatedCashAfter:650000,atomicReplayPass:true,
  legacySaveUnchanged:true,checksum:before.checksum};
}
if(require.main===module){try{
 const [profile,seed,out='economy-v2-e26-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(out,{recursive:true});
 fs.writeFileSync(path.join(out,'atomic-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E26 PASS '+JSON.stringify(r));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
