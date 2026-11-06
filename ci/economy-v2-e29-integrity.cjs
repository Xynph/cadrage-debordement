'use strict';
// E2.9 sandbox. A trustworthy independent monotonic anchor is supplied by the caller.
// NO native save / gameplay integration. Local fixture authority is NOT a production trust root.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const Store=require('./economy-v2-durable-store.cjs');
const A=require('../dist/economy-v2-atomic-adapter.js');
const check=(p,m)=>{if(!p)throw Error(m)};
const stable=x=>Array.isArray(x)?'['+x.map(stable).join(',')+']':
 x&&typeof x==='object'?'{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+stable(x[k])).join(',')+'}':JSON.stringify(x);
const digest=x=>crypto.createHash('sha256').update(stable(x)).digest('hex');
const proof=x=>({revision:x.revision,sha256:x.sha256});
const eq=(a,b)=>a&&b&&a.revision===b.revision&&a.sha256===b.sha256;
function verifyAuthority(authority){
 check(authority&&typeof authority.current==='function'&&typeof authority.compareAndSet==='function','Independent trusted authority required');
}
function verifiedRead(file,authority){
 verifyAuthority(authority);const state=Store.read(file),anchor=authority.current();
 check(eq(proof(state),anchor),'Rollback, unanchored commit or tampered authority: STOP');
 return state;
}
function withGuard(file,work){
 const lock=file+'.e29-guard';
 try{fs.mkdirSync(lock,0o700)}catch(e){if(e.code==='EEXIST')throw Error('E2.9 concurrent guard busy or orphaned: STOP');throw e}
 try{return work()}finally{fs.rmdirSync(lock)}
}
function transact(file,authority,operation,opts={}){
 verifyAuthority(authority);check(typeof operation==='function','Pure operation required');
 return withGuard(file,()=>{
  const prev=verifiedRead(file,authority);
  // E2.7 makes an atomic disk commit; the separately trusted authority must
  // advance monotonically. Crash between them => detectable STOP, never silent repair.
  const next=Store.transact(file,operation,opts);
  if(eq(proof(prev),proof(next)))return next;
  check(next.revision===prev.revision+1,'Invalid revision advance');
  const accepted=authority.compareAndSet(proof(prev),proof(next));
  check(accepted===true,'Authority did not attest commit: STOP');
  check(eq(authority.current(),proof(next)),'Authority attestation not durable: STOP');
  return next;
 });
}
function bootstrap(file,authority){
 verifyAuthority(authority);
 const state=Store.read(file);
 check(state.revision===0&&A.validate(state.state),'Bootstrap only a fresh empty accounting sandbox');
 check(authority.current()===null,'Authority already initialized');
 check(authority.compareAndSet(null,proof(state))===true,'Bootstrap rejected');
 return verifiedRead(file,authority);
}
function confirmedRecovery(file,authority,approve){
 verifyAuthority(authority);check(typeof approve==='function','Explicit recovery approval required');
 const state=Store.read(file),anchor=authority.current();
 check(anchor&&state.revision===anchor.revision+1,'Only one pending disk commit can be reconciled');
 check(A.validate(state.state),'Invalid candidate ledger');
 const evidence=Object.freeze({anchoredRevision:anchor.revision,anchoredHash:anchor.sha256,
  candidateRevision:state.revision,candidateHash:state.sha256});
 check(approve(evidence)===true,'Recovery not approved');
 check(eq(authority.current(),anchor)&&eq(proof(Store.read(file)),proof(state)),'Recovery evidence changed');
 check(authority.compareAndSet(anchor,proof(state))===true,'Authority recovery CAS denied');
 return verifiedRead(file,authority);
}
function fixtureAuthority(anchorFile,key){
 check(Buffer.isBuffer(key)&&key.length>=32,'Fixture key must be at least 32 bytes');
 const sign=v=>crypto.createHmac('sha256',key).update('CD-E29-ANCHOR-V1\n'+stable(v)).digest('hex');
 const current=()=>{
  if(!fs.existsSync(anchorFile))return null;
  const x=JSON.parse(fs.readFileSync(anchorFile,'utf8'));
  check(x&&x.version===1&&Number.isSafeInteger(x.revision)&&x.revision>=0&&/^[a-f0-9]{64}$/.test(x.sha256||''),'Invalid anchor');
  check(typeof x.mac==='string'&&/^[a-f0-9]{64}$/.test(x.mac),'Unsigned anchor');
  check(crypto.timingSafeEqual(Buffer.from(x.mac,'hex'),Buffer.from(sign({revision:x.revision,sha256:x.sha256}),'hex')),'Anchor signature mismatch');
  return {revision:x.revision,sha256:x.sha256};
 };
 const compareAndSet=(expected,next)=>{
  check(next&&Number.isSafeInteger(next.revision)&&/^[a-f0-9]{64}$/.test(next.sha256||''),'Invalid next anchor');
  const previous=current();
  if(!(expected===null&&previous===null)&&!eq(expected,previous))return false;
  if(previous)check(next.revision===previous.revision+1,'Anchor must advance monotonically');
  else check(next.revision===0,'Invalid first anchor');
  const data={version:1,...next,mac:sign(next)};
  const dir=path.dirname(anchorFile),tmp=anchorFile+'.'+process.pid+'.'+crypto.randomBytes(8).toString('hex')+'.tmp';
  let renamed=false;
  try{const fd=fs.openSync(tmp,'wx',0o600);
   try{fs.writeFileSync(fd,JSON.stringify(data));fs.fsyncSync(fd)}finally{fs.closeSync(fd)}
   fs.renameSync(tmp,anchorFile);renamed=true;
   const dfd=fs.openSync(dir,'r');try{fs.fsyncSync(dfd)}finally{fs.closeSync(dfd)}
  }finally{if(!renamed){try{fs.unlinkSync(tmp)}catch(e){if(e.code!=='ENOENT')throw e}}}
  return true;
 };
 return Object.freeze({current,compareAndSet});
}
module.exports=Object.freeze({verifiedRead,transact,bootstrap,confirmedRecovery,fixtureAuthority});
