'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {parseArgs,execute}=require('../tools/data05-pipeline.cjs');
test('default is zero-credit zero-network audit',()=>{assert.equal(parseArgs([]).limit,0);assert.equal(parseArgs([]).budget,0);assert.throws(()=>parseArgs(['--limit','1']),/ack-lnr-access/);assert.throws(()=>parseArgs(['--budget','-1']),/Invalid/);});
test('transport and real collector are wired with injectable mocks',async()=>{
 let used=0;const ref={id:'lnr:1',club:'clermont',url:'https://top14.lnr.fr/joueur/1-name'};
 const result=await execute({limit:1,budget:0,dir:'/tmp/test-data05'},{roster:()=>[ref],transportFactory:()=>({direct:async()=>{used++;return '<h1>Player</h1>25 ans'},scrape:async()=>{throw Error('must not scrape')},stats:()=>({firecrawlCalls:0})}),resilience:{classify:()=>({stop:false})},run:async opts=>{const p=await opts.http(ref.url);assert.equal(p.name,'Player');return{cached:1,newlyFetched:1,remaining:[],errors:[],firecrawlCalls:0}}});
 assert.equal(used,1);assert.equal(result.transport.firecrawlCalls,0);
});
test('stopped response forbids Firecrawl fallback',async()=>{
 let f=0;const ref={id:'lnr:1',club:'clermont',url:'https://top14.lnr.fr/joueur/1-name'};
 await execute({limit:1,budget:1,dir:'/tmp/test-data05'},{roster:()=>[ref],transportFactory:()=>({direct:async()=>{throw Object.assign(Error('403'),{status:403})},scrape:async()=>{f++;return '# Player'},stats:()=>({firecrawlCalls:f})}),resilience:{classify:()=>({stop:true})},run:async opts=>{await assert.rejects(opts.http(ref.url),/403/);await assert.rejects(opts.fallback(ref.url),/stopped/i);return{errors:[],remaining:[]}}});
 assert.equal(f,0);
});

test('paid Firecrawl refusal locks both subsequent fallback and HTTP',async()=>{
 for(const status of [401,402,403,429]){
  let scraped=0, direct=0;
  const ref={id:'lnr:1',club:'clermont',url:'https://top14.lnr.fr/joueur/1-name'};
  await execute({limit:2,budget:2,key:'dummy',dir:'/tmp/data05-stop'},{roster:()=>[ref],transportFactory:()=>({
   direct:async()=>{direct++;throw Error('temporary direct failure')},
   scrape:async()=>{scraped++;throw Object.assign(Error('Firecrawl '+status),{status})},
   stats:()=>({firecrawlCalls:scraped})
  }),resilience:require('../tools/data05-resilience.cjs'),run:async opts=>{
   await assert.rejects(opts.http(ref.url));
   await assert.rejects(opts.fallback(ref.url),/Firecrawl/);
   await assert.rejects(opts.fallback(ref.url),/stopped/i);
   await assert.rejects(opts.http(ref.url),/stopped/i);
   return {errors:[],remaining:[],cached:240,firecrawlCalls:scraped};
  }});
  assert.equal(scraped,1);assert.equal(direct,1);
 }
});

test('collection serializes all workers to guarantee stop ordering',async()=>{
 assert.throws(()=>parseArgs(['--concurrency','2']),/Invalid/);
 await assert.rejects(execute({limit:2,budget:2,concurrency:2},{roster:()=>[]}),/Concurrent DATA-05/);
});
test('real transport scrape through execute: HTTP 403 from paid API stops after first reserved call',async()=>{
 const {createTransport}=require('../tools/data05-transport.cjs');
 const ref={id:'lnr:1',club:'club',url:'https://top14.lnr.fr/joueur/1-name'};
 for(const status of [401,402,403,429]){
  let paid=0;
  const transportFactory=()=>createTransport({firecrawlKey:'fake',firecrawlBudget:3,retries:0,fetcher:async(url)=>{
    if(url==='https://api.firecrawl.dev/v2/scrape'){paid++;return {ok:false,status}}
    return {ok:false,status:500};
  }});
  const result=await execute({limit:1,budget:3,key:'fake',concurrency:1},{roster:()=>[ref],transportFactory,run:async opts=>{
    await assert.rejects(opts.http(ref.url),/500/);
    await assert.rejects(opts.fallback(ref.url),/HTTP/);
    await assert.rejects(opts.fallback(ref.url),/stopped/);
    await assert.rejects(opts.http(ref.url),/stopped/);
    return {errors:[{id:ref.id}],remaining:[ref.id],firecrawlCalls:1};
  }});
  assert.equal(paid,1);assert.equal(result.transport.firecrawlCalls,1);
 }
});
