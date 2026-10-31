'use strict';
const fs=require('node:fs'),path=require('node:path');
const collector=require('./data05-unified.cjs');
// Run from branch containing PR #134, or provide a compatible adapter explicitly.
function resilience(){
 try{return require('./data05-resilience.cjs')}catch(e){if(e.code==='MODULE_NOT_FOUND')throw Error('PR #134 resilience module not integrated; do not start live collection');throw e}
}
async function runProtected({root=path.resolve(__dirname,'..'),dir,limit=0,budget=0,concurrency=1,delayMs=1200,http,fallback,key}={}){
 if(!Number.isInteger(limit)||limit<0||!Number.isInteger(budget)||budget<0)throw Error('Invalid collection limit/budget');
 const {classify,withRetries,reserveBudget}=resilience();
 const state={used:0,stopped:false};
 async function safeHttp(url){
  if(state.stopped)throw Error('Collection stopped');
  const task=http||async()=>{const ctl=new AbortController(),timer=setTimeout(()=>ctl.abort(),15000);try{const resp=await fetch(url,{signal:ctl.signal});if(!resp.ok)throw Object.assign(Error('LNR HTTP '+resp.status),{status:resp.status});return collector.parseHtml(await resp.text())}finally{clearTimeout(timer)}};
  return withRetries(()=>task(url),{maxRetries:1,onStop:()=>{state.stopped=true}});
 }
 async function safeFallback(url,apiKey){
  if(state.stopped||!reserveBudget(state,budget))throw Error('Firecrawl budget exhausted or collection stopped');
  if(!fallback)throw Error('No Firecrawl adapter supplied');
  return withRetries(()=>fallback(url,apiKey),{maxRetries:0,onStop:()=>{state.stopped=true}});
 }
 const result=await collector.run({root,dir,list:collector.loadRoster(root),limit,budget:Math.min(budget,Number.MAX_SAFE_INTEGER),concurrency,delayMs,http:safeHttp,fallback:safeFallback,key});
 return {...result,guardedFirecrawlCalls:state.used,stopped:state.stopped};
}
if(require.main===module)runProtected({limit:Number(process.argv.includes('--limit')?process.argv[process.argv.indexOf('--limit')+1]:0),budget:0}).then(r=>console.log(JSON.stringify({...r,remaining:r.remaining.length},null,2))).catch(e=>{console.error(e.message);process.exitCode=1});
module.exports={runProtected};
