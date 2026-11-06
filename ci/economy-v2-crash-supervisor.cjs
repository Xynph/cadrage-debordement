'use strict';
// E2.8 sandbox-only controlled recovery of an orphaned E2.7 lock.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const Store=require('./economy-v2-durable-store.cjs');
const check=(ok,msg)=>{if(!ok)throw Error(msg)};
const safeInt=x=>Number.isSafeInteger(x)&&x>0;
function inspect(file){
 const lock=file+'.lock';
 const st=fs.lstatSync(lock);
 check(st.isDirectory()&&!st.isSymbolicLink(),'Unsafe lock type');
 const ownerPath=path.join(lock,'owner.json'),ost=fs.lstatSync(ownerPath);
 check(ost.isFile()&&!ost.isSymbolicLink()&&ost.size>0&&ost.size<=4096,'Unsafe owner record');
 const owner=JSON.parse(fs.readFileSync(ownerPath,'utf8'));
 check(owner&&safeInt(owner.pid)&&typeof owner.hostname==='string'&&owner.hostname.length>0,'Invalid lock owner');
 const entries=fs.readdirSync(lock);
 check(entries.length===1&&entries[0]==='owner.json','Unexpected lock contents');
 const live=(()=>{try{process.kill(owner.pid,0);return true}catch(e){if(e.code==='ESRCH')return false;if(e.code==='EPERM')return true;throw e}})();
 return {owner,live,local:owner.hostname===os.hostname(),lock,ownerPath,
   lockIdentity:{dev:st.dev,ino:st.ino},ownerIdentity:{dev:ost.dev,ino:ost.ino},
   store:Store.read(file)};
}
// No silent or automatic recovery. Operator explicitly approves a lock snapshot.
function recover(file,{authorize,expectedPid,expectedRevision}={}){
 check(typeof authorize==='function','Explicit human recovery authorizer required');
 const evidence=inspect(file);
 check(evidence.local,'Foreign-host lock cannot be recovered automatically');
 check(!evidence.live,'Lock owner process still live or status uncertain');
 check(expectedPid===evidence.owner.pid&&expectedRevision===evidence.store.revision,'Stale operator approval');
 const approval=Object.freeze({pid:evidence.owner.pid,hostname:evidence.owner.hostname,
   revision:evidence.store.revision,sha256:evidence.store.sha256,lockInode:evidence.lockIdentity.ino,
   ownerInode:evidence.ownerIdentity.ino});
 check(authorize(approval)===true,'Operator explicitly refused recovery');
 const current=inspect(file);
 check(!current.live&&current.local
  &&current.owner.pid===evidence.owner.pid
  &&current.lockIdentity.ino===evidence.lockIdentity.ino
  &&current.lockIdentity.dev===evidence.lockIdentity.dev
  &&current.ownerIdentity.ino===evidence.ownerIdentity.ino
  &&current.ownerIdentity.dev===evidence.ownerIdentity.dev
  &&current.store.revision===evidence.store.revision
  &&current.store.sha256===evidence.store.sha256,'Lock or ledger changed during approval');
 // Refuse if another actor introduced new entries. Still a local advisory protocol, not a security boundary against hostile writers.
 fs.unlinkSync(evidence.ownerPath);fs.rmdirSync(evidence.lock);
 return {recovered:true,previousOwner:evidence.owner.pid,revision:evidence.store.revision,sha256:evidence.store.sha256};
}
function retryContention(work,maxAttempts=50){
 check(typeof work==='function'&&safeInt(maxAttempts)&&maxAttempts<=1000,'Invalid retry limits');
 let conflicts=0;
 for(let i=0;i<maxAttempts;i++){
  try{return {result:work(),conflicts}}
  catch(e){if(!/Concurrent writer or orphan lock: fail closed/.test(e.message))throw e;conflicts++;}
 }
 throw Error('Contention limit exceeded: fail closed');
}
module.exports=Object.freeze({inspect,recover,retryContention});
