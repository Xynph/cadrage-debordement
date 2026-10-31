'use strict';
const {test}=require('node:test'); const assert=require('node:assert/strict');
const {createTransport,validUrl,kind}=require('../tools/data05-transport.cjs');
const url='https://top14.lnr.fr/joueur/862-barnabe-massa';
test('source whitelist and transient classification',()=>{assert.equal(validUrl(url),url);assert.throws(()=>validUrl('https://evil.test/joueur/10-test'));assert.equal(kind({status:429}),'stop');assert.equal(kind({status:503}),'retry')});
test('direct retry when transient but stop on 403',async()=>{let n=0;const t=createTransport({fetcher:async()=>{if(n++===0)return {ok:false,status:503};return {ok:true,text:async()=>'<h1>Player</h1>'}},pauseFn:async()=>{}});assert.match(await t.direct(url),/Player/);assert.equal(n,2);const block=createTransport({fetcher:async()=>({ok:false,status:403})});await assert.rejects(block.direct(url),/403/);assert.equal(block.stats().stopped,true)});
test('Firecrawl credits reserved even on failed HTTP and never exceeded',async()=>{let n=0;const t=createTransport({firecrawlKey:'test-only',firecrawlBudget:1,fetcher:async()=>{n++;return{ok:false,status:500}}});await assert.rejects(t.scrape(url),/500/);await assert.rejects(t.scrape(url),/exhausted/);assert.equal(n,1);assert.equal(t.stats().firecrawlCalls,1)});
test('Firecrawl live response shape parsed and no leaked credentials in stats',async()=>{const t=createTransport({firecrawlKey:'test-only',firecrawlBudget:1,fetcher:async(_url,opts)=>{assert.equal(opts.method,'POST');return{ok:true,json:async()=>({success:true,data:{markdown:'# Barnabe MASSA'}})}}});assert.equal(await t.scrape(url),'# Barnabe MASSA');assert.deepEqual(t.stats(),{firecrawlCalls:1,stopped:false,reason:null})});

test('Firecrawl authorization and quota refusals lock paid transport without retry',async()=>{
 for(const status of [401,402,403,429]){
  let calls=0;
  const transport=createTransport({firecrawlKey:'dummy',firecrawlBudget:3,fetcher:async()=>{calls++;return {ok:false,status}},retries:0});
  await assert.rejects(transport.scrape('https://top14.lnr.fr/joueur/1-name'),/HTTP/);
  await assert.rejects(transport.scrape('https://top14.lnr.fr/joueur/1-name'),/Transport stopped/);
  assert.equal(calls,1);
  assert.equal(transport.stats().firecrawlCalls,1);
  assert.equal(transport.stats().stopped,true);
 }
});
test('zero paid-call budget performs no Firecrawl request',async()=>{
 let calls=0;
 const transport=createTransport({firecrawlKey:'dummy',firecrawlBudget:0,fetcher:async()=>{calls++;throw Error('network should not happen')}});
 await assert.rejects(transport.scrape('https://top14.lnr.fr/joueur/1-name'),/budget exhausted/);
 assert.equal(calls,0);
 assert.equal(transport.stats().firecrawlCalls,0);
});
