'use strict';
// E2.1 harness-only observer. Never imported into dist, never persisted into a save.
const assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs');
const Shadow=require('../dist/economy-v2-shadow.js');
function snap(g){return N.data(g,'({season:S.season,round:S.round,phase:S.phase,manager:S.club,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash}))})')}
function traceAction(g,action,label){
 const before=snap(g);
 // Native model is unmodified: interception exists only for the duration of this call.
 g.run(`globalThis.__e21CashTrace=(function(){
  const clubs=S.clubs.map(c=>{
   const original=Object.getOwnPropertyDescriptor(c,'cash');
   if(!original||!('value' in original)||!original.configurable||!original.writable)throw Error('Cash cannot be observed safely');
   let value=original.value;
   Object.defineProperty(c,'cash',{enumerable:original.enumerable,configurable:true,get(){return value},set(next){
    if(!Number.isSafeInteger(next))throw Error('Noninteger native cash write');
    const old=value;value=next;
    if(next!==old){
     const stack=(new Error('cash-write')).stack||'';
     const site=stack.split('\\n').slice(2).map(x=>x.trim()).find(x=>!x.includes('__e21CashTrace'))||'unknown';
     events.push({clubId:c.id,delta:next-old,site,old,next});
    }
   }});
   return {c,original,initial:original.value,read:()=>value};
  });
  const events=[];
  return {events,stop(){
   for(const x of clubs)Object.defineProperty(x.c,'cash',{...x.original,value:x.read()});
   return clubs.map(x=>({id:x.c.id,opening:x.initial,closing:x.read()}));
  }};
 })()`);
 let outcome,failed;
 try{outcome=action()}catch(e){failed=e}
 const records=N.data(g,'__e21CashTrace.events');
 const touched=N.data(g,'__e21CashTrace.stop()');
 delete g.ctx.__e21CashTrace;
 if(failed)throw failed;
 const after=snap(g),old=new Map(before.clubs.map(c=>[c.id,c.cash])),recovered=new Map(touched.map(c=>[c.id,c]));
 assert.equal(records.filter(r=>r.site==='unknown').length,0,'Missing source location');
 for(const c of after.clubs){
  const deltas=records.filter(x=>x.clubId===c.id).reduce((s,x)=>s+x.delta,0);
  assert.equal(deltas,c.cash-old.get(c.id),'Missing native cash mutation for '+label+' club '+c.id);
  assert.equal(recovered.get(c.id)?.opening,old.get(c.id),'Observer wrong opening');
  assert.equal(recovered.get(c.id)?.closing,c.cash,'Observer changed cash');
 }
 const observation=Shadow.observe(before,after,[],label);
 const movements=records.map(({clubId,delta,site})=>({clubId,delta,site}));
 return {before,after,movements,observation,outcome,identified:movements.length,unknownSource:0,anomalies:0};
}
function groupSites(trace,aggregates){
 for(const x of trace.movements){
  const k=x.site,entry=aggregates[k]||(aggregates[k]={count:0,grossPositive:0,grossNegative:0,net:0,clubs:{}});
  entry.count++;entry.net+=x.delta;
  if(x.delta>=0)entry.grossPositive+=x.delta;else entry.grossNegative-=x.delta;
  entry.clubs[x.clubId]=(entry.clubs[x.clubId]||0)+1;
 }
}
module.exports={snap,traceAction,groupSites};

if(require.main===module&&process.argv.includes('--self-test')){
 const normal=N.fresh(0,827381),observed=N.fresh(0,827381);
 const baseline=JSON.stringify(N.data(normal)),instrumented=JSON.stringify(N.data(observed));
 assert.equal(instrumented,baseline,'Fresh native state changed');
 const referenceLedger=N.round(normal,N.newStats());
 const trace=traceAction(observed,()=>N.round(observed,N.newStats()),'deterministic-parity');
 assert.deepEqual(trace.outcome,referenceLedger,'Ledger mutated by observation');
 assert.equal(JSON.stringify(N.data(observed)),JSON.stringify(N.data(normal)),'Observer changed native game state');
 assert.equal(JSON.stringify(N.data(observed,'createSaveDocument()')),JSON.stringify(N.data(normal,'createSaveDocument()')),'Observer changed native save export');
 console.log('E21 PARITY PASS: native game state, ledger and save document identical');
}
