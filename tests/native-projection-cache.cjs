'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
test('deux lectures réutilisent les projections VM sans partager les objets ni garder un reçu',()=>{
 const original=vm.runInContext;let count=0,b,n=0;
 vm.runInContext=function(source,...rest){if(source==='JSON.stringify(nativeSystems.project())')count++;return original.call(this,source,...rest);};
 try{
  b=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'oval-cache-')),seed:27,now:1700000000000});
  const call=(command,payload={})=>b.handle({id:++n,command,payload});
  assert.equal(call('new_career',{mode:'common',club:29}).ok,true);
  const one=call('snapshot');count=0;const two=call('snapshot');assert.equal(count,0,'pas de nouvelle projection identique');assert.deepEqual(two.model,one.model);
  two.model.club.name='altéré par lecteur';assert.notEqual(call('snapshot').model.club.name,two.model.club.name);
  const exp=call('export');assert.equal(typeof exp.model.meta.exportText,'string');assert.equal(call('snapshot').model.meta.exportText,undefined);
  count=0;assert.equal(call('commande_inconnue').ok,false);assert.ok(count>0,'invalidation même lors d’un refus');
 }finally{vm.runInContext=original;b?.close();}
});
