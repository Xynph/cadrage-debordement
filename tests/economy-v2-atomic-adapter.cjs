'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const A=require('../dist/economy-v2-atomic-adapter.js'),E1=require('../dist/economy-v2-core.js');
const o={clubId:'a',obligationId:'bill1',amount:300,due:'2028-03',confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'attested1'};
const p={clubId:'a',obligationId:'bill1',paymentId:'payment1',paidPeriod:'2028-03',receiptRef:'receipt1'};
const trust=(type,record)=>['obligation','receipt'].includes(type)&&!!record;
const funded=()=>{const x=A.create(['a','b']);return {...x,ledger:E1.injectCapital(x.ledger,{clubId:'a',eventId:'capital',period:'2028-01',amount:1000})}};
const ready=()=>A.mature(A.register(funded(),o,trust),'2028-03');
test('E2.6 empty state is valid and legacy is not inspected',()=>{const x=A.create(['a']);assert.equal(A.validate(x),true);assert.equal(x.due.obligations.length,0)});
test('E2.6 fail closed without trusted source or with negative proof',()=>{
 assert.throws(()=>A.register(funded(),o),/verifier/);
 assert.throws(()=>A.register(funded(),o,()=>false),/not authenticated/);
 assert.throws(()=>A.settle(ready(),p,()=>false),/not authenticated/);
});
test('E2.6 register links E1 commitment to E2.5 without cash change',()=>{
 const x=funded(),y=A.register(x,o,trust);
 assert.equal(E1.snapshot(x.ledger,'a').cash,E1.snapshot(y.ledger,'a').cash);
 assert.equal(y.ledger.commitments.length,1);
 assert.equal(y.due.obligations.length,1);
 assert.strictEqual(A.register(y,o,trust),y);
});
test('E2.6 exact settlement reduces cash once and replay is unchanged',()=>{
 const x=ready(),cash=E1.snapshot(x.ledger,'a').cash,y=A.settle(x,p,trust);
 assert.equal(E1.snapshot(y.ledger,'a').cash,cash-300);
 assert.equal(E1.snapshot(x.ledger,'a').cash,cash);
 assert.strictEqual(A.settle(y,p,trust),y);
 assert.equal(y.ledger.events.filter(e=>e.eventId==='payment1').length,1);
 assert.equal(y.due.payments.length,1);
 assert.throws(()=>A.settle(y,{...p,receiptRef:'new-receipt'},trust),/Conflicting/);
});
test('E2.6 insufficient funds cannot produce paid receipt or cash deficit',()=>{
 let x=A.create(['a']);x=A.mature(A.register(x,o,trust),'2028-03');
 const original=JSON.stringify(x);
 assert.throws(()=>A.settle(x,p,trust),/Invalid asset/);
 assert.equal(JSON.stringify(x),original);
 assert.equal(x.due.payments.length,0);
});
test('E2.6 premature payment is atomic',()=>{
 const x=A.register(funded(),o,trust),before=JSON.stringify(x);
 assert.throws(()=>A.settle(x,p,trust),/Payment before maturity|Commitment not due/);
 assert.equal(JSON.stringify(x),before);
});
test('E2.6 forged receipt rejects global reuse across clubs',()=>{
 let x=funded();
 x={...x,ledger:E1.injectCapital(x.ledger,{clubId:'b',eventId:'capital-b',period:'2028-01',amount:1000})};
 x=A.register(x,o,trust);x=A.register(x,{...o,clubId:'b',obligationId:'bill2',evidenceRef:'attested2'},trust);
 x=A.mature(x,'2028-03');x=A.settle(x,p,trust);
 assert.throws(()=>A.settle(x,{clubId:'b',obligationId:'bill2',paymentId:'payment2',paidPeriod:'2028-03',receiptRef:'receipt1'},trust),/reused globally/);
 assert.throws(()=>A.register(x,{...o,clubId:'b',obligationId:'bill3'},trust),/Evidence reused globally/);
});
test('E2.6 crash-before-commit and crash-after-commit replay',()=>{
 const x=ready();let candidate=A.settle(x,p,trust);
 assert.equal(x.due.payments.length,0,'interrupted transaction leaves original untouched');
 const durable=JSON.stringify(candidate),reloaded=A.restore(durable);
 const after=A.settle(reloaded,p,trust);
 assert.strictEqual(after,reloaded);
 assert.equal(E1.snapshot(after.ledger,'a').cash,700);
});
test('E2.6 corrupt or partial serialized transaction is rejected',()=>{
 const y=A.settle(ready(),p,trust),bad=JSON.parse(JSON.stringify(y));
 bad.due.payments=[];
 assert.throws(()=>A.restore(JSON.stringify(bad)),/Paid status mismatch/);
 const bad2=JSON.parse(JSON.stringify(y));bad2.ledger.commitments[0].settled=false;
 assert.throws(()=>A.restore(JSON.stringify(bad2)),/Unmatched E1 obligation|payment binding mismatch/i);
});
test('E2.6 historic summary retains previous unpaid obligations',()=>{
 const x=A.mature(A.register(funded(),o,trust),'2028-03');
 const paid=A.settle(x,{...p,paidPeriod:'2028-04'},trust);
 assert.equal(A.summary(paid,'a','2028-03').obligations.dueUnpaid,300);
 assert.equal(A.summary(paid,'a','2028-04').obligations.dueUnpaid,0);
});
test('E2.6 no duplicate documentary evidence with distinct club',()=>{
 let x=A.register(funded(),o,trust);
 assert.throws(()=>A.register(x,{...o,clubId:'b',obligationId:'bill-other'},trust),/Evidence reused globally/);
});
test('E2.6 fail-closed unknown state version',()=>{const x=funded();x.version=2;assert.throws(()=>A.validate(x),/Invalid adapter state/)});
