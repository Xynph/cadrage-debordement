'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process'),readline=require('node:readline');
const {createBridge}=require('../native/engine/worker.cjs'),{context}=require('./native-reference-harness.cjs');
const limit=8*1024*1024,envelope=17*1024*1024,folder=fs.mkdtempSync(path.join(os.tmpdir(),'native-save-limits-'));
let sequence=0;
function good(b,command,payload={}){const r=b.handle({id:++sequence,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;}
function pad(text){return text+' '.repeat(limit-Buffer.byteLength(text));}
async function main(){
 const b=createBridge({dataDir:path.join(folder,'direct'),seed:13,now:1700000000000});let original;
 try{
  const m=settleClubMeetings(good(b,'new_career',{club:0}),(command,payload)=>good(b,command,payload)),file=path.join(m.meta.dataDir,'donnees.json');original=good(b,'export').meta.exportText;
  const exact=pad(original);assert.equal(Buffer.byteLength(exact),limit);
  good(b,'import',{text:exact});assert.equal(good(b,'export').meta.exportText,original,'Document exactement8Mio accepté sans modifier état');
  const bytes=fs.readFileSync(file);
  for(const text of [exact+' ', 'é'.repeat(limit/2+1), 'x'.repeat(limit+1)]){
   const result=b.handle({id:++sequence,command:'import',payload:{text}});assert.equal(result.ok,false);assert.match(result.error,/volumineux.*8 Mio/i);
   assert.equal(good(b,'export').meta.exportText,original);assert.deepEqual(fs.readFileSync(file),bytes,'Refus UTF8 conserve disque/RNG/horloge');
  }
  const reference=context();reference.ctx.text=exact;assert.equal(reference.run('parseSaveDocument(text).checksum'),JSON.parse(original).checksum);
  for(const text of ['é'.repeat(limit/2+1),'😀'.repeat(limit/4+1)]){reference.ctx.text=text;assert.throws(()=>reference.run('parseSaveDocument(text)'),/volumineux.*8 Mio/i,'Parseur partagé borne les octets UTF8 avant JSON.parse');}
  reference.ctx.text='é'.repeat(limit/2);assert.throws(()=>reference.run('parseSaveDocument(text)'),/JSON.*illisible/i,'Exactement8Mio UTF8 atteint le parseur JSON');
  reference.ctx.text=original;reference.run('parseSaveDocument(text)');
  assert.equal(require('../native/engine/worker.cjs').IMPORT_LIMIT_BYTES,reference.run('SAVE_LIMIT'),'Plafond commun moteur natif/parseur partagé');
 }finally{b.close();}
 // Actual private JSON-lines process, with both escaping and an exact envelope.
 const child=spawn(process.execPath,[path.resolve(__dirname,'../native/engine/worker.cjs'),'--data-dir',path.join(folder,'pipes')],{stdio:['pipe','pipe','pipe'],windowsHide:true});
 const lines=readline.createInterface({input:child.stdout}),pending=[];let errors='';child.stderr.on('data',d=>errors+=d);lines.on('line',line=>pending.shift().resolve(JSON.parse(line)));
 child.on('error',error=>{for(const p of pending.splice(0))p.reject(error);});child.on('exit',code=>{for(const p of pending.splice(0))p.reject(Error('Worker arrêté avant réponse : '+code));});
 const watchdog=setTimeout(()=>child.kill(),30000);
 const send=line=>new Promise((resolve,reject)=>{pending.push({resolve,reject});child.stdin.write(line+'\n',error=>{if(error)reject(error);});});
 try{
  assert.equal((await send(JSON.stringify({id:1,command:'new_career',payload:{club:0}}))).ok,true);
  const doc=JSON.parse(original);doc.padding='\\'.repeat(3*1024*1024);const escaped=pad(JSON.stringify(doc));
  const request=JSON.stringify({id:2,command:'import',payload:{text:escaped}});assert.ok(Buffer.byteLength(request)>12*1024*1024&&Buffer.byteLength(request)<envelope);
  assert.equal((await send(request)).ok,true,'Import8Mio avec échappement massif traverse le vrai transport');
  const base=JSON.stringify({id:3,command:'snapshot'}),exact=base+' '.repeat(envelope-Buffer.byteLength(base));
  assert.equal((await send(exact)).ok,true,'Enveloppe exacte17Mio acceptée');
  const refused=await send(exact+' ');assert.equal(refused.ok,false);assert.match(refused.error,/Message trop volumineux/);
  assert.equal((await send(JSON.stringify({id:4,command:'snapshot'}))).ok,true,'Worker reste utilisable après refus transport');
  assert.equal((await send(JSON.stringify({id:5,command:'shutdown'}))).ok,true);
  child.stdin.end();await new Promise((resolve,reject)=>{child.once('exit',code=>code===0?resolve():reject(Error('worker exit '+code)));});assert.equal(errors,'');
 }finally{clearTimeout(watchdog);if(child.exitCode===null)child.kill();lines.close();}
 if(process.env.CD_SAVE_LIMIT_REPRO_PROFILE){
  const source=process.env.CD_SAVE_LIMIT_REPRO_PROFILE,target=path.join(folder,'s28','PrototypeGodot');fs.mkdirSync(target,{recursive:true});fs.copyFileSync(path.join(source,'donnees.json'),path.join(target,'donnees.json'));
  let resumed=createBridge({dataDir:target,now:1700000000000});try{
   const before=good(resumed,'export').meta.exportText;assert.ok(Buffer.byteLength(before)>5*1024*1024&&Buffer.byteLength(before)<=limit,'Fixture réelle dépasse5Mio');
   const disk=JSON.parse(fs.readFileSync(path.join(target,'donnees.json'),'utf8'));good(resumed,'import',{text:before});assert.equal(good(resumed,'export').meta.exportText,before);
   const after=JSON.parse(fs.readFileSync(path.join(target,'donnees.json'),'utf8'));assert.equal(after.seed,disk.seed);assert.equal(after.clock,disk.clock);for(const key of Object.keys(disk.store))if(key!=='bdt-before-import')assert.ok(after.store[key]===disk.store[key],'Stockage carrière conservé : '+key);
   good(resumed,'shutdown');resumed=createBridge({dataDir:target,now:1700000000000});assert.equal(good(resumed,'export').meta.exportText,before,'Reprise exacte de la vraie carrièreS28');
   fs.writeFileSync(path.join(folder,'s28-export.json'),before);console.log('S28 réelle : '+Buffer.byteLength(before)+' octets, import/export/reprise état+RNG+horloge+stockage PASS.');
  }finally{resumed.close();}
 }else console.log('SKIP fixture réelleS28 : CD_SAVE_LIMIT_REPRO_PROFILE absent.');
 console.log('Plafonds UTF8 :8Mio/17Mio, parseur partagé, refus atomiques et vraiJSON-lines PASS. Preuves : '+folder);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
