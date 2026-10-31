'use strict';
// Audit REEL de tools/data05-unified.cjs sur les 15 fichiers du checkout, zero reseau.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {run,loadRoster}=require('../tools/data05-unified.cjs');
const ROOT=path.resolve(__dirname,'..');
test('240 profils historiques importés puis relus sans HTTP ni crédit, sur données réelles',async()=>{
 const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'lnr05-real-import-'));
 let calls=0;
 const block=async()=>{calls++;throw Error('FORBIDDEN NETWORK')};
 try{
  const list=loadRoster(ROOT);assert.equal(list.length,1592);
  const args={root:ROOT,dir:tmp,list,limit:0,budget:0,delayMs:0,key:null,http:block,fallback:block};
  const first=await run(args);
  assert.equal(first.target,1592);assert.equal(first.imported,240);assert.equal(first.cached,240);
  assert.equal(first.newlyFetched,0);assert.equal(first.firecrawlCalls,0);assert.equal(first.errors.length,0);
  assert.equal(first.remaining.length,1352);assert.equal(calls,0,'aucun acces HTTP direct ou Firecrawl');
  const exported=JSON.parse(fs.readFileSync(path.join(tmp,'players.json'),'utf8'));
  assert.equal(exported.dateScope,'collection-time-not-2026-07-01');
  assert.equal(exported.players.length,240);
  assert.equal(new Set(exported.players.map(p=>p.id)).size,240);
  assert.ok(exported.players.every(p=>p.validAtJuly1===false&&p.birthDate===null));
  const ref=new Map(list.map(p=>[p.id,p]));
  assert.ok(exported.players.every(p=>ref.has(p.id)&&ref.get(p.id).club===p.club&&ref.get(p.id).url===p.url));
  const second=await run(args);
  assert.equal(second.imported,0);assert.equal(second.cached,240);assert.equal(second.newlyFetched,0);
  assert.equal(second.firecrawlCalls,0);assert.equal(calls,0);
  console.log('REAL DATA05 IMPORT PASS: 240/240, 1592 catalogue, 0 network, 0 credit, resume unchanged');
 }finally{fs.rmSync(tmp,{recursive:true,force:true})}
});
