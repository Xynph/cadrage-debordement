'use strict';
// E2.7 R&D sandbox: local POSIX filesystem only; never referenced by native saves/gameplay.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const A=require('../dist/economy-v2-atomic-adapter.js');
const check=(v,m)=>{if(!v)throw Error(m)};
const canonical=v=>{
 if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';
 if(v&&typeof v==='object'){const keys=Object.keys(v).sort();return '{'+keys.map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}'}
 return JSON.stringify(v);
};
const keyOk=k=>Buffer.isBuffer(k)&&k.length>=32;
const mac=(key,kind,record)=>crypto.createHmac('sha256',key).update('CD-E27-PROOF-V1\n'+kind+'\n'+canonical(record)).digest('hex');
function sealFixture(key,kind,document){
 check(keyOk(key)&&['obligation','receipt'].includes(kind)&&document&&typeof document==='object','Invalid signing fixture');
 return {schema:1,kind,document:JSON.parse(JSON.stringify(document)),signature:mac(key,kind,document)};
}
function verifier(key,envelope){
 check(keyOk(key),'Trusted verification key required');
 return (kind,record)=>{
  if(!envelope||envelope.schema!==1||envelope.kind!==kind||!['obligation','receipt'].includes(kind))return false;
  if(canonical(record)!==canonical(envelope.document))return false;
  const signature=envelope.signature;
  if(typeof signature!=='string'||!/^[a-f0-9]{64}$/.test(signature))return false;
  return crypto.timingSafeEqual(Buffer.from(signature,'hex'),Buffer.from(mac(key,kind,record),'hex'));
 };
}
const hash=x=>crypto.createHash('sha256').update(canonical(x)).digest('hex');
const envelope=(revision,state)=>({format:'cd-economy-e27-sandbox',version:1,revision,state,sha256:hash({revision,state})});
function checkEnvelope(e){
 check(e&&e.format==='cd-economy-e27-sandbox'&&e.version===1&&Number.isSafeInteger(e.revision)&&e.revision>=0,'Invalid durable format');
 check(e.sha256===hash({revision:e.revision,state:e.state}),'Durable checksum mismatch');
 A.validate(e.state);return e;
}
function read(file){
 check(fs.existsSync(file),'Durable sandbox not initialized');
 check(fs.lstatSync(file).isFile(),'Nonregular sandbox file');
 return checkEnvelope(JSON.parse(fs.readFileSync(file,'utf8')));
}
function atomicWrite(file,data,failpoint){
 const dir=path.dirname(file),tmp=path.join(dir,'.'+path.basename(file)+'.'+process.pid+'.'+crypto.randomBytes(8).toString('hex')+'.tmp');
 let fd,renamed=false;
 try{
  fd=fs.openSync(tmp,'wx',0o600);fs.writeFileSync(fd,JSON.stringify(data));fs.fsyncSync(fd);fs.closeSync(fd);fd=undefined;
  if(failpoint==='before-rename')throw Error('Simulated crash before rename');
  fs.renameSync(tmp,file);renamed=true;
  const dfd=fs.openSync(dir,'r');try{fs.fsyncSync(dfd)}finally{fs.closeSync(dfd)}
  if(failpoint==='after-rename')throw Error('Simulated crash after rename');
 }finally{
  if(fd!==undefined)fs.closeSync(fd);
  if(!renamed){try{fs.unlinkSync(tmp)}catch(e){if(e.code!=='ENOENT')throw e}}
 }
}
function locked(file,operation){
 const dir=path.dirname(file);check(fs.statSync(dir).isDirectory(),'Invalid sandbox directory');
 const lock=file+'.lock';
 try{fs.mkdirSync(lock,0o700)}catch(e){if(e.code==='EEXIST')throw Error('Concurrent writer or orphan lock: fail closed');throw e}
 try{
  fs.writeFileSync(path.join(lock,'owner.json'),JSON.stringify({pid:process.pid,hostname:os.hostname()}),{flag:'wx',mode:0o600});
  return operation();
 }finally{
  // A real process crash leaves a visible orphan lock: never silently steal it.
  try{fs.rmSync(lock,{recursive:true})}catch(e){throw Error('Unable to release durable lock: '+e.message)}
 }
}
function initialize(file,clubIds){
 check(typeof file==='string'&&file.length>0,'Invalid sandbox path');
 return locked(file,()=>{
  check(!fs.existsSync(file),'Sandbox already exists');
  const e=envelope(0,A.create(clubIds));checkEnvelope(e);atomicWrite(file,e);return e;
 });
}
function transact(file,transform,{failpoint}={}){
 check(typeof transform==='function','Pure transaction callback required');
 return locked(file,()=>{
  const before=read(file),after=transform(before.state);
  A.validate(after);
  if(after===before.state||canonical(after)===canonical(before.state))return before;
  const next=envelope(before.revision+1,after);checkEnvelope(next);
  atomicWrite(file,next,failpoint);
  return next;
 });
}
function register(file,document,signed,key,opts){
 return transact(file,s=>A.register(s,document,verifier(key,signed)),opts);
}
function mature(file,period,opts){return transact(file,s=>A.mature(s,period),opts)}
function settle(file,receipt,signed,key,opts){
 return transact(file,s=>A.settle(s,receipt,verifier(key,signed)),opts);
}
module.exports=Object.freeze({initialize,read,transact,register,mature,settle,sealFixture,verifier});
