'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const C=require('../dist/economy-v2-due-contract.js'),N=require('./career-resilience/native.cjs');
const base={clubId:'club-1',obligationId:'invoice-01',amount:300,due:'2027-03',
 confirmedPeriod:'2027-01',evidenceKind:'invoice-approved',evidenceRef:'invoice-source-01'};
const pay={clubId:'club-1',obligationId:'invoice-01',paymentId:'bank-payment-01',
 paidPeriod:'2027-03',receiptRef:'bank-receipt-01'};
test('E2.5: empty V1 ledger has no invented amounts',()=>{
 const w=C.create();assert.equal(C.validate(w),true);
 assert.deepEqual(C.summary(w,'club-1','2027-03'),{clubId:'club-1',asOfPeriod:'2027-03',
 verifiedDocuments:0,registeredFuture:0,dueUnpaid:0,dueCount:0,paidDocuments:0,
 unmeasuredLegacyLiabilities:null});
});
test('E2.5: explicit documentary evidence is mandatory',()=>{
 const w=C.create();
 for(const field of ['evidenceRef','evidenceKind','confirmedPeriod','amount','due']){
  const b={...base};delete b[field];assert.throws(()=>C.register(w,b),/Explicit documentary evidence/);
 }
 assert.throws(()=>C.register(w,{...base,evidenceKind:'forecast'}),/Explicit documentary evidence/);
 assert.throws(()=>C.register(w,{...base,confirmedPeriod:'2027-04'}),/Explicit documentary evidence/);
});
test('E2.5: confirmed future item is not yet payable',()=>{
 let w=C.register(C.create(),base);
 assert.equal(C.summary(w,'club-1','2027-02').registeredFuture,300);
 assert.equal(C.summary(w,'club-1','2027-02').dueUnpaid,0);
 assert.throws(()=>C.settle(w,pay),/before maturity/);
 const untouched=C.mature(w,'2027-02');assert.strictEqual(untouched,w);
 w=C.mature(w,'2027-03');assert.equal(C.summary(w,'club-1','2027-03').dueUnpaid,300);
});
test('E2.5: payment is idempotent, receipt assigned once, no double charge',()=>{
 let w=C.mature(C.register(C.create(),base),'2027-03');const input=w;
 w=C.settle(w,pay);assert.equal(C.summary(w,'club-1','2027-03').dueUnpaid,0);
 assert.equal(w.payments.length,1);assert.strictEqual(C.settle(w,pay),w);
 assert.equal(input.payments.length,0,'Immutable update');
 assert.throws(()=>C.settle(w,{...pay,paymentId:'other'}),/Already settled/);
});
test('E2.5: distinct obligations cannot reuse one payment or receipt',()=>{
 let w=C.register(C.create(),base);
 w=C.register(w,{...base,obligationId:'invoice-02',evidenceRef:'invoice-source-02'});
 w=C.mature(w,'2027-03');w=C.settle(w,pay);
 for(const dup of [{...pay,obligationId:'invoice-02'},{
  ...pay,obligationId:'invoice-02',paymentId:'bank-payment-02'}]){
  assert.throws(()=>C.settle(w,dup),/already assigned/);
 }
 assert.equal(w.payments.length,1);
});
test('E2.5: replay and conflicting documentary evidence are rejected',()=>{
 const w=C.register(C.create(),base);
 assert.strictEqual(C.register(w,base),w);
 assert.throws(()=>C.register(w,{...base,amount:301}),/Conflicting documentary replay/);
 assert.throws(()=>C.register(w,{...base,obligationId:'new-invoice'}),/Document already recognized/);
});
test('E2.5: tampered V1 records are rejected on import',()=>{
 let w=C.mature(C.register(C.create(),base),'2027-03');w=C.settle(w,pay);
 const tampered=JSON.parse(JSON.stringify(w));tampered.payments[0].amount=301;
 assert.throws(()=>C.validate(tampered),/does not match/);
 tampered.payments[0].amount=300;tampered.payments.push({...tampered.payments[0]});
 assert.throws(()=>C.validate(tampered),/Duplicate/);
});
test('E2.5: JSON export/import preserves verified receipts and maturity',()=>{
 let w=C.mature(C.register(C.create(),base),'2027-03');w=C.settle(w,pay);
 const revived=JSON.parse(JSON.stringify(w));assert.equal(C.validate(revived),true);
 assert.deepEqual(C.summary(revived,'club-1','2027-03'),C.summary(w,'club-1','2027-03'));
});
test('E2.5: crisis of insufficient cash never generates synthetic credit',()=>{
 let w=C.register(C.create(),{...base,amount:1000000000});
 w=C.mature(w,'2027-03');
 assert.equal(w.payments.length,0);assert.equal(w.obligations[0].status,'due');
 assert.equal(C.summary(w,'club-1','2027-03').dueUnpaid,1000000000);
 // An actual bank receipt is mandatory; merely reaching due date does not settle anything.
});
test('E2.5: 15 annual maturities preserve one payment per document',()=>{
 let w=C.create();for(let year=2027;year<=2041;year++){
  const ref='invoice-'+year,period=year+'-03';
  w=C.register(w,{...base,obligationId:ref,evidenceRef:ref,due:period,
   confirmedPeriod:year+'-01',amount:year});
  w=C.mature(w,period);
  w=C.settle(w,{clubId:'club-1',obligationId:ref,paymentId:'pay-'+year,
   paidPeriod:period,receiptRef:'receipt-'+year});
 }
 assert.equal(w.payments.length,15);
 assert.equal(C.summary(w,'club-1','2041-12').dueUnpaid,0);
 assert.equal(C.validate(w),true);
});
test('E2.5: legacy save remains byte-equivalent after read-only preview',()=>{
 const g=N.fresh(),before=N.data(g,'createSaveDocument()'),source=JSON.stringify(before);
 const view=C.legacyPreview(before.state);
 assert.equal(view.legacyUnmeasuredLiabilities,null);assert.equal(view.contractualEvidenceCreated,0);
 assert.equal(view.ledger.obligations.length,0);
 assert.equal(JSON.stringify(before),source);
 const after=N.data(g,'createSaveDocument()');
 assert.deepEqual(after.state,before.state);assert.equal(after.checksum,before.checksum);
});
test('E2.5: no automatic migration from offers, salary or debt',()=>{
 const g=N.fresh(),s=N.data(g);
 const preview=C.legacyPreview(s);
 assert.equal(preview.observedClubs,14);assert.equal(preview.activation,'not-activated');
 assert.equal(preview.ledger.payments.length,0);
 assert.equal(preview.ledger.obligations.length,0);
});

test('E2.5: historical as-of reporting retains unpaid due before later receipt',()=>{
 let w=C.register(C.create(),base);w=C.mature(w,'2027-03');
 w=C.settle(w,{...pay,paidPeriod:'2027-04'});
 assert.equal(C.summary(w,'club-1','2027-03').dueUnpaid,300);
 assert.equal(C.summary(w,'club-1','2027-03').paidDocuments,0);
 assert.equal(C.summary(w,'club-1','2027-04').dueUnpaid,0);
 assert.equal(C.summary(w,'club-1','2027-04').paidDocuments,1);
});
