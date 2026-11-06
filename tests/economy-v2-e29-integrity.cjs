'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process');
const I=require('../ci/economy-v2-e29-integrity.cjs'),S=require('../ci/economy-v2-durable-store.cjs');
const E1=require('../dist/economy-v2-core.js');
const key=Buffer.alloc(32,91),cwd=path.resolve(__dirname,'..');
function fixture(fn){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e29-')),file=path.join(dir,'ledger.json'),anchor=path.join(dir,'external-witness.json');
 try{S.initialize(file,['a']);const authority=I.fixtureAuthority(anchor,key);I.bootstrap(file,authority);return fn({dir,file,anchor,authority})}
 finally{fs.rmSync(dir,{recursive:true,force:true})}
}
const book=(file,authority,eventId)=>I.transact(file,authority,x=>({...x,ledger:E1.income(x.ledger,{clubId:'a',eventId,period:'2028-03',amount:100,category:'ticket'})}));
test('E2.9: external anchor accepts a genuine increment and rejects replayed storage snapshot',()=>fixture(({file,authority})=>{
 const old=fs.readFileSync(file,'utf8');
 const b=book(file,authority,'income1');
 assert.equal(b.revision,1);
 assert.equal(I.verifiedRead(file,authority).state.ledger.balances.a.cash,100);
 fs.writeFileSync(file,old);
 assert.throws(()=>I.verifiedRead(file,authority),/Rollback, unanchored/);
 assert.throws(()=>book(file,authority,'income2'),/Rollback, unanchored/);
}));
test('E2.9: detects recomputed local checksum tampering without authorized anchor',()=>fixture(({file,authority})=>{
 book(file,authority,'income1');
 const obj=JSON.parse(fs.readFileSync(file,'utf8'));
 obj.revision=0;
 fs.writeFileSync(file,JSON.stringify(obj));
 assert.throws(()=>I.verifiedRead(file,authority),/checksum mismatch/i);
}));
test('E2.9: signed anchor rejects modified revision, digest, and unsigned authority',()=>fixture(({file,anchor,authority})=>{
 book(file,authority,'income1');
 const previous=fs.readFileSync(anchor,'utf8');
 for(const mutate of [x=>{x.revision=22},x=>{x.sha256='a'.repeat(64)},x=>{delete x.mac}]){
  const obj=JSON.parse(previous);mutate(obj);fs.writeFileSync(anchor,JSON.stringify(obj));
  assert.throws(()=>I.verifiedRead(file,authority),/signature|Unsigned/i);
 }
 fs.writeFileSync(anchor,previous);assert.equal(I.verifiedRead(file,authority).revision,1);
}));
test('E2.9: crash after disk commit before authority endorsement stops, explicit recovery only',()=>fixture(({file,authority})=>{
 assert.throws(()=>I.transact(file,authority,x=>({...x,ledger:E1.income(x.ledger,{clubId:'a',eventId:'crash',period:'2028-03',amount:100})}),{failpoint:'after-rename'}),/Simulated crash/);
 assert.equal(S.read(file).revision,1);
 assert.equal(authority.current().revision,0);
 assert.throws(()=>I.verifiedRead(file,authority),/Rollback, unanchored/);
 assert.throws(()=>I.confirmedRecovery(file,authority,()=>false),/not approved/);
 assert.throws(()=>I.confirmedRecovery(file,authority,()=>true&&false),/not approved/);
 I.confirmedRecovery(file,authority,x=>x.anchoredRevision===0&&x.candidateRevision===1);
 assert.equal(I.verifiedRead(file,authority).state.ledger.balances.a.cash,100);
 const second=book(file,authority,'next');assert.equal(second.revision,2);
}));
test('E2.9: reject forged recovery when gap exceeds one or authority is unavailable',()=>fixture(({file,authority})=>{
 book(file,authority,'income1');
 assert.throws(()=>I.confirmedRecovery(file,authority,()=>true),/Only one pending/);
 assert.throws(()=>I.verifiedRead(file,{current:()=>null,compareAndSet:()=>true}),/Rollback, unanchored/);
 assert.throws(()=>I.verifiedRead(file,{}),/Independent trusted authority/);
}));
test('E2.9: evidence rejected if changed, no payable or phantom cash created',()=>fixture(({file,authority})=>{
 const original=JSON.stringify(I.verifiedRead(file,authority));
 const doc={clubId:'a',obligationId:'invoice',amount:300,due:'2028-03',confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'source'};
 const fake=S.sealFixture(Buffer.alloc(32,77),'obligation',doc);
 assert.throws(()=>I.transact(file,authority,x=>require('../dist/economy-v2-atomic-adapter.js').register(x,{...doc,amount:301},S.verifier(Buffer.alloc(32,77),fake))),/not authenticated/);
 assert.equal(JSON.stringify(I.verifiedRead(file,authority)),original);
}));
const worker=`
const I=require('./ci/economy-v2-e29-integrity.cjs'),E1=require('./dist/economy-v2-core.js');
const file=process.argv[1],anchorPath=process.argv[2],n=Number(process.argv[3]);
const a=I.fixtureAuthority(anchorPath,Buffer.alloc(32,91));
for(let j=0;j<2;j++){
 let accepted=false;
 for(let attempt=0;attempt<5000;attempt++){
  try{I.transact(file,a,x=>({...x,ledger:E1.income(x.ledger,{clubId:'a',eventId:'worker'+n+'-'+j,period:'2028-03',amount:100})}));accepted=true;break}
  catch(e){if(!/E2.9 concurrent guard busy or orphaned: STOP/.test(e.message)){process.stderr.write(e.stack);process.exit(2)}
   Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,2);
  }
 }
 if(!accepted)process.exit(3);
}
`;
test('E2.9: eight independent workers, sixteen atomic ledger commits and monotonic witness',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e29-multi-')),file=path.join(dir,'ledger.json'),anchorFile=path.join(dir,'witness.json');
 try{
  S.initialize(file,['a']);const authority=I.fixtureAuthority(anchorFile,key);I.bootstrap(file,authority);
  const launch=n=>new Promise((resolve,reject)=>{
   const p=spawn(process.execPath,['-e',worker,file,anchorFile,String(n)],{cwd,stdio:['ignore','ignore','pipe']});
   let err='';p.stderr.on('data',x=>err+=x);
   p.on('error',reject);p.on('close',(code,signal)=>code===0?resolve():reject(Error('worker '+n+': '+code+'/'+signal+' '+err)));
  });
  await Promise.all(Array.from({length:8},(_,i)=>launch(i)));
  const state=I.verifiedRead(file,authority);
  assert.equal(state.revision,16);
  assert.equal(state.state.ledger.balances.a.cash,1600);
  assert.equal(state.state.ledger.events.length,16);
  assert.equal(fs.existsSync(file+'.e29-guard'),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
