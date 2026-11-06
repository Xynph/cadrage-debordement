'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const E1=require('../dist/economy-v2-core.js'),S=require('../ci/economy-v2-durable-store.cjs');
const secret=Buffer.alloc(32,71);
const obligation={clubId:'a',obligationId:'invoice',amount:300,due:'2028-03',confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'document-2028-03'};
const receipt={clubId:'a',obligationId:'invoice',paymentId:'bank-transaction',paidPeriod:'2028-03',receiptRef:'receipt-2028-03'};
const signed=(kind,x)=>S.sealFixture(secret,kind,x);
function fixture(fn){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e27-'));const file=path.join(dir,'sandbox.json');try{return fn(file,dir)}finally{fs.rmSync(dir,{recursive:true,force:true})}}
function ready(file,amount=1000){
 S.initialize(file,['a','b']);
 S.transact(file,s=>({...s,ledger:E1.injectCapital(s.ledger,{clubId:'a',eventId:'test-capital',period:'2028-01',amount})}));
 S.register(file,obligation,signed('obligation',obligation),secret);
 S.mature(file,'2028-03');
}
test('E2.7: documentary signature authenticates exact object, rejects wrong key and mutation',()=>{
 const proof=signed('obligation',obligation);
 assert.equal(S.verifier(secret,proof)('obligation',obligation),true);
 assert.equal(S.verifier(Buffer.alloc(32,72),proof)('obligation',obligation),false);
 assert.equal(S.verifier(secret,proof)('obligation',{...obligation,amount:301}),false);
 assert.equal(S.verifier(secret,proof)('receipt',obligation),false);
 assert.equal(S.verifier(secret,{...proof,signature:'X'})('obligation',obligation),false);
 assert.throws(()=>S.verifier(Buffer.alloc(12),proof),/key/);
});
test('E2.7: register rejects unsigned, forged, reused and tampered evidence',()=>fixture(file=>{
 S.initialize(file,['a']);
 const old=fs.readFileSync(file,'utf8');
 assert.throws(()=>S.register(file,obligation,{...signed('obligation',obligation),signature:'0'.repeat(64)},secret),/authenticated/);
 assert.equal(fs.readFileSync(file,'utf8'),old);
 S.register(file,obligation,signed('obligation',obligation),secret);
 assert.throws(()=>S.register(file,{...obligation,obligationId:'other'},signed('obligation',obligation),secret),/authenticated/);
}));
test('E2.7: persistent settlement and replay across a new process debits once',()=>fixture(file=>{
 ready(file);const proof=signed('receipt',receipt);
 const child=`const S=require('./ci/economy-v2-durable-store.cjs');const file=process.argv[1],receipt=JSON.parse(process.argv[2]),signed=JSON.parse(process.argv[3]);S.settle(file,receipt,signed,Buffer.alloc(32,71));`;
 const invoke=()=>spawnSync(process.execPath,['-e',child,file,JSON.stringify(receipt),JSON.stringify(proof)],{cwd:path.join(__dirname,'..'),encoding:'utf8'});
 const a=invoke();assert.equal(a.status,0,a.stderr);
 const first=S.read(file);assert.equal(first.state.ledger.balances.a.cash,700);
 const b=invoke();assert.equal(b.status,0,b.stderr);
 const second=S.read(file);assert.equal(second.revision,first.revision);
 assert.equal(second.state.due.payments.length,1);
 assert.equal(second.state.ledger.events.filter(e=>e.eventId==='bank-transaction').length,1);
}));
test('E2.7: crash before rename leaves old JSON intact and can retry',()=>fixture(file=>{
 ready(file);const old=fs.readFileSync(file,'utf8');
 assert.throws(()=>S.settle(file,receipt,signed('receipt',receipt),secret,{failpoint:'before-rename'}),/Simulated crash/);
 assert.equal(fs.readFileSync(file,'utf8'),old);
 assert.equal(S.read(file).state.due.payments.length,0);
 S.settle(file,receipt,signed('receipt',receipt),secret);
 assert.equal(S.read(file).state.ledger.balances.a.cash,700);
}));
test('E2.7: crash after rename persists committed bundle; replay remains idempotent',()=>fixture(file=>{
 ready(file);
 assert.throws(()=>S.settle(file,receipt,signed('receipt',receipt),secret,{failpoint:'after-rename'}),/Simulated crash/);
 const stored=S.read(file),revision=stored.revision;
 assert.equal(stored.state.ledger.balances.a.cash,700);
 S.settle(file,receipt,signed('receipt',receipt),secret);
 assert.equal(S.read(file).revision,revision);
}));
test('E2.7: insolvency rejects without partial durable state',()=>fixture(file=>{
 ready(file,100);const before=fs.readFileSync(file,'utf8');
 assert.throws(()=>S.settle(file,receipt,signed('receipt',receipt),secret),/Invalid asset/);
 assert.equal(fs.readFileSync(file,'utf8'),before);
}));
test('E2.7: corrupted or half-written JSON is rejected, never reinitialized',()=>fixture(file=>{
 S.initialize(file,['a']);const data=JSON.parse(fs.readFileSync(file,'utf8'));data.state.version=9;
 fs.writeFileSync(file,JSON.stringify(data));
 assert.throws(()=>S.read(file),/checksum mismatch/);
 assert.throws(()=>S.initialize(file,['a']),/already exists/);
}));
test('E2.7: process lock conflicts fail closed without writing',()=>fixture(file=>{
 ready(file);const before=fs.readFileSync(file,'utf8');
 fs.mkdirSync(file+'.lock');fs.writeFileSync(path.join(file+'.lock','owner.json'),'{"pid":987654}');
 const child=`const S=require('./ci/economy-v2-durable-store.cjs');try{S.mature(process.argv[1],'2028-04');process.exit(3)}catch(e){if(!/orphan lock/.test(e.message))process.exit(4)}`;
 const r=spawnSync(process.execPath,['-e',child,file],{cwd:path.join(__dirname,'..')});
 assert.equal(r.status,0,'Independent writer must fail closed');
 assert.throws(()=>S.mature(file,'2028-04'),/orphan lock/);
 assert.equal(fs.readFileSync(file,'utf8'),before);
 fs.rmSync(file+'.lock',{recursive:true});
}));
test('E2.7: expiry + double proof receipt cannot skip commitment',()=>fixture(file=>{
 ready(file);S.settle(file,receipt,signed('receipt',receipt),secret);
 const previous=fs.readFileSync(file,'utf8');
 const changed={...receipt,paymentId:'second'};
 assert.throws(()=>S.settle(file,changed,signed('receipt',changed),secret),/Conflicting receipt replay/);
 assert.equal(fs.readFileSync(file,'utf8'),previous);
}));
