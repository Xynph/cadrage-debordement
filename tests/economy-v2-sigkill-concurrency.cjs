'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync,spawn}=require('node:child_process');
const Store=require('../ci/economy-v2-durable-store.cjs'),Sup=require('../ci/economy-v2-crash-supervisor.cjs'),E1=require('../dist/economy-v2-core.js');
const key=Buffer.alloc(32,77),cwd=path.resolve(__dirname,'..');
const bill={clubId:'a',obligationId:'invoice',amount:300,due:'2028-03',confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'verified-source'};
const receipt={clubId:'a',obligationId:'invoice',paymentId:'bank-payment',paidPeriod:'2028-03',receiptRef:'verified-receipt'};
const sign=(kind,x)=>Store.sealFixture(key,kind,x);
function scratch(fn){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e28-')),file=path.join(dir,'ledger.json');try{return fn(file,dir)}finally{fs.rmSync(dir,{recursive:true,force:true})}}
function funded(file,amount=5000){Store.initialize(file,['a']);Store.transact(file,s=>({...s,ledger:E1.injectCapital(s.ledger,{clubId:'a',eventId:'capital',period:'2028-01',amount})}));}
function ready(file){funded(file);Store.register(file,bill,sign('obligation',bill),key);Store.mature(file,'2028-03')}
const killScript=`
const fs=require('node:fs'),S=require('./ci/economy-v2-durable-store.cjs');
const file=process.argv[1],mode=process.argv[2];
const original=fs.renameSync;
fs.renameSync=(from,to)=>{
 if(to===file&&mode==='before'){process.kill(process.pid,'SIGKILL');throw Error('kill failed')}
 const out=original(from,to);
 if(to===file&&mode==='after'){process.kill(process.pid,'SIGKILL');throw Error('kill failed')}
 return out;
};
const r={clubId:'a',obligationId:'invoice',paymentId:'bank-payment',paidPeriod:'2028-03',receiptRef:'verified-receipt'};
const key=Buffer.alloc(32,77);S.settle(file,r,S.sealFixture(key,'receipt',r),key);
`;
test('E2.8: SIGKILL before rename preserves unpaid ledger; operator recovers stale lock and retries',()=>scratch(file=>{
 ready(file);const initial=Store.read(file);
 const child=spawnSync(process.execPath,['-e',killScript,file,'before'],{cwd,encoding:'utf8'});
 assert.equal(child.signal,'SIGKILL',child.stderr);
 assert.equal(Store.read(file).revision,initial.revision);
 assert.equal(Store.read(file).state.due.payments.length,0);
 assert.throws(()=>Store.settle(file,receipt,sign('receipt',receipt),key),/orphan lock/);
 assert.throws(()=>Sup.recover(file,{expectedPid:child.pid,expectedRevision:initial.revision,authorize:()=>false}),/refused/);
 const evidence=Sup.inspect(file);assert.equal(evidence.live,false);assert.equal(evidence.local,true);
 const result=Sup.recover(file,{expectedPid:evidence.owner.pid,expectedRevision:initial.revision,authorize:x=>x.sha256===initial.sha256});
 assert.equal(result.recovered,true);
 Store.settle(file,receipt,sign('receipt',receipt),key);
 assert.equal(Store.read(file).state.ledger.balances.a.cash,4700);
 assert.equal(Store.read(file).state.due.payments.length,1);
}));
test('E2.8: SIGKILL after rename leaves whole paid ledger; operator recovery + replay never debits twice',()=>scratch(file=>{
 ready(file);const initial=Store.read(file);
 const child=spawnSync(process.execPath,['-e',killScript,file,'after'],{cwd,encoding:'utf8'});
 assert.equal(child.signal,'SIGKILL',child.stderr);
 const recovered=Store.read(file);assert.equal(recovered.revision,initial.revision+1);
 assert.equal(recovered.state.due.payments.length,1);
 assert.equal(recovered.state.ledger.balances.a.cash,4700);
 const evidence=Sup.inspect(file);
 assert.throws(()=>Sup.recover(file,{expectedPid:evidence.owner.pid,expectedRevision:initial.revision,authorize:()=>true}),/Stale operator approval/);
 Sup.recover(file,{expectedPid:evidence.owner.pid,expectedRevision:recovered.revision,authorize:()=>true});
 Store.settle(file,receipt,sign('receipt',receipt),key);
 assert.equal(Store.read(file).revision,recovered.revision);
 assert.equal(Store.read(file).state.ledger.balances.a.cash,4700);
}));
test('E2.8: refuse recovery of living lock owner or foreign host',()=>scratch(file=>{
 funded(file);const lock=file+'.lock';fs.mkdirSync(lock);
 fs.writeFileSync(path.join(lock,'owner.json'),JSON.stringify({pid:process.pid,hostname:os.hostname()}));
 assert.throws(()=>Sup.recover(file,{expectedPid:process.pid,expectedRevision:1,authorize:()=>true}),/still live/);
 fs.writeFileSync(path.join(lock,'owner.json'),JSON.stringify({pid:99999999,hostname:'remote-host'}));
 assert.throws(()=>Sup.recover(file,{expectedPid:99999999,expectedRevision:1,authorize:()=>true}),/Foreign-host/);
}));
test('E2.8: authenticated signatures reject falsified amounts, receipt reuse and wrong key',()=>scratch(file=>{
 ready(file);const before=fs.readFileSync(file,'utf8');
 assert.throws(()=>Store.settle(file,{...receipt,paidPeriod:'2028-04'},sign('receipt',receipt),key),/authenticated/);
 assert.throws(()=>Store.settle(file,receipt,sign('receipt',receipt),Buffer.alloc(32,76)),/authenticated/);
 assert.throws(()=>Store.settle(file,receipt,{...sign('receipt',receipt),signature:'a'.repeat(64)},key),/authenticated/);
 assert.equal(fs.readFileSync(file,'utf8'),before);
 Store.settle(file,receipt,sign('receipt',receipt),key);
 assert.throws(()=>Store.settle(file,{...receipt,paymentId:'duplicate'},sign('receipt',{...receipt,paymentId:'duplicate'}),key),/Conflicting receipt replay/);
}));
const worker=`
const S=require('./ci/economy-v2-durable-store.cjs'),Sup=require('./ci/economy-v2-crash-supervisor.cjs');
const file=process.argv[1],i=Number(process.argv[2]),key=Buffer.alloc(32,77);
const receipt={clubId:'a',obligationId:'ob'+i,paymentId:'payment'+i,paidPeriod:'2028-03',receiptRef:'bank'+i};
const x=Sup.retryContention(()=>S.settle(file,receipt,S.sealFixture(key,'receipt',receipt),key),10000);
process.stdout.write(JSON.stringify({conflicts:x.conflicts})+'\\n');
`;
test('E2.8: 12 concurrent real writer processes settle 12 distinct bills exactly once',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e28-concurrent-')),file=path.join(dir,'ledger.json');
 try{
  funded(file,50000);
  for(let i=0;i<12;i++){
   const ob={clubId:'a',obligationId:'ob'+i,amount:100,due:'2028-03',confirmedPeriod:'2028-01',evidenceKind:'invoice-approved',evidenceRef:'doc'+i};
   Store.register(file,ob,sign('obligation',ob),key);
  }
  Store.mature(file,'2028-03');
  const launch=i=>new Promise((resolve,reject)=>{
   const child=spawn(process.execPath,['-e',worker,file,String(i)],{cwd,stdio:['ignore','pipe','pipe']});
   let stderr='',stdout='';child.stderr.on('data',x=>stderr+=x);child.stdout.on('data',x=>stdout+=x);
   child.on('error',reject);child.on('close',(code,signal)=>code===0?resolve(JSON.parse(stdout.trim())):reject(Error('worker '+i+' exit='+code+' signal='+signal+': '+stderr)));
  });
  const results=await Promise.all(Array.from({length:12},(_,i)=>launch(i)));
  const ledger=Store.read(file);
  assert.equal(results.length,12);
  assert.equal(ledger.state.due.payments.length,12);
  assert.equal(ledger.state.ledger.events.filter(e=>e.category==='commitment-verified').length,12);
  assert.equal(ledger.state.ledger.balances.a.cash,48800);
  assert.equal(ledger.revision,26); // capital + 12 registrations + maturity + 12 settlements
  assert.equal(fs.existsSync(file+'.lock'),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
