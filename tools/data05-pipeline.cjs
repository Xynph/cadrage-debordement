'use strict';
const path = require('node:path');
const unified = require('./data05-unified.cjs');
function loadTransport() {
 try { return require('./data05-transport.cjs').createTransport; }
 catch (e) { if(e.code==='MODULE_NOT_FOUND') throw Error('PR #137 transport dependency missing'); throw e; }
}
function loadResilience() {
 try { return require('./data05-resilience.cjs'); }
 catch (e) { if(e.code==='MODULE_NOT_FOUND') throw Error('PR #134 resilience dependency missing'); throw e; }
}
function parseArgs(args) {
 function get(k,d){const i=args.indexOf(k);return i<0?d:args[i+1];}
 const result={limit:Number(get('--limit','0')),budget:Number(get('--budget','0')),concurrency:Number(get('--concurrency','1')),delayMs:Number(get('--delay-ms','1200')),dir:path.resolve(get('--output','modding/data05-unified-output'))};
 if(!Number.isInteger(result.limit)||result.limit<0||result.limit>1592||!Number.isInteger(result.budget)||result.budget<0||!Number.isInteger(result.concurrency)||result.concurrency<1||result.concurrency>1||!Number.isInteger(result.delayMs)||result.delayMs<1000)throw Error('Invalid collection parameters');
 if(result.limit>0&&!args.includes('--ack-lnr-access'))throw Error('Confirm LNR access rules using --ack-lnr-access before live collection');
 return result;
}
async function execute(options={},deps={}) {
 if((options.concurrency??1)!==1)throw Error('Concurrent DATA-05 collection is disabled until fail-closed proof');
 const root=options.root||path.resolve(__dirname,'..');
 const roster=(deps.roster||unified.loadRoster)(root);
 const createTransport=deps.transportFactory||loadTransport();
 const resilience=deps.resilience||loadResilience();
 const transport=createTransport({fetcher:deps.fetcher,firecrawlKey:options.key||process.env.FIRECRAWL_API_KEY,firecrawlBudget:options.budget||0});
 let stopped=false;
 async function http(url){
   if(stopped)throw Error('Collection stopped');
   try {
     const html=await transport.direct(url);
     return unified.parseHtml(html);
   }catch(e){if(resilience.classify(e).stop)stopped=true;throw e;}
 }
 async function fallback(url){
   if(stopped)throw Error('Collection stopped');
   try {
     const markdown=await transport.scrape(url);
     return unified.parseMarkdown(markdown);
   }catch(e){if(resilience.classify(e).stop)stopped=true;throw e;}
 }
 const report=await (deps.run||unified.run)({root,dir:options.dir||path.join(root,'modding/data05-unified-output'),list:roster,http,fallback,key:options.key||process.env.FIRECRAWL_API_KEY,limit:options.limit??0,budget:options.budget??0,concurrency:options.concurrency??1,delayMs:options.delayMs??1200});
 const cost=transport.stats();
 if(cost.firecrawlCalls>(options.budget||0))throw Error('Firecrawl budget exceeded');
 return {...report,transport:cost};
}
if(require.main===module) {
 let opts;try{opts=parseArgs(process.argv.slice(2))}catch(e){console.error(e.message);process.exit(1)}
 execute(opts).then(r=>{console.log(JSON.stringify({...r,remaining:r.remaining.length},null,2));if(r.errors?.length)process.exitCode=1}).catch(e=>{console.error(e.stack);process.exitCode=1});
}
module.exports={parseArgs,execute};
