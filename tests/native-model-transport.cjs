'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawn}=require('node:child_process'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),readline=require('node:readline');
const {apply}=require('../native/engine/model-transport.cjs');
test('vrai stdio : petit delta, refus, reprise complète et client historique',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-wire-')),child=spawn(process.execPath,[path.resolve(__dirname,'../native/engine/worker.cjs'),'--data-dir',dir],{env:{...process.env,CD_GODOT_SEED:'27'},stdio:['pipe','pipe','pipe']});
 let pending,errors='',n=0,model,revision=0;child.stderr.on('data',s=>errors+=s);
 readline.createInterface({input:child.stdout}).on('line',line=>{const done=pending;pending=null;done?.({response:JSON.parse(line),bytes:Buffer.byteLength(line)});});
 const send=(command,payload={},wire=true,base=revision)=>new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>reject(Error('Réponse stdio expirée : '+errors)),30000);
  pending=result=>{clearTimeout(timer);resolve(result);};child.stdin.write(JSON.stringify({id:++n,command,payload,...(wire?{transport:{version:1,base}}:{})})+'\n');
 });
 const accept=r=>{model=apply(model,revision,r);revision=r.transport.revision;return model;};
 try{
  accept((await send('snapshot')).response);
  const created=await send('new_career',{mode:'common',club:29});assert.equal(created.response.ok,true);accept(created.response);
  accept((await send('snapshot')).response);const before=structuredClone(model);
  const small=await send('snapshot');assert.equal(small.response.transport.full,false);assert.ok(small.bytes<2000,small.bytes);assert.deepEqual(accept(small.response),before);
  const refused=await send('inconnue');assert.equal(refused.response.ok,false);accept(refused.response);
  const full=await send('snapshot',{},true,-10);assert.equal(full.response.transport.full,true);accept(full.response);
  const legacy=await send('snapshot',{},false);assert.equal(legacy.response.transport,undefined);assert.deepEqual(legacy.response.model,model);
  await send('shutdown',{},false);
 }finally{child.stdin.end();if(child.exitCode===null)child.kill();}
});
