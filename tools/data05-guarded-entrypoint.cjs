'use strict';
const path=require('node:path');
const fs=require('node:fs');
const unified=require('./data05-unified.cjs');
function dependencies(){
  const required=['./data05-preflight.cjs','./data05-pipeline.cjs','./data05-transport.cjs','./data05-resilience.cjs'];
  for(const file of required){try{require.resolve(file)}catch(e){throw Error('DATA-05 dependency unavailable: '+file+' (#137/#138/#139 must be integrated)')}}
  return {preflight:require('./data05-preflight.cjs'),pipeline:require('./data05-pipeline.cjs')};
}
function sourceProfiles(root){
  const files=[...['data05-bulk','data05-bulk2','data05-bulk3'].flatMap(d=>Array.from({length:5},(_,i)=>path.join(root,'modding',d,'profiles-'+String(i+1).padStart(2,'0')+'.json')))];
  const result=[];
  for(const file of files){
    const doc=JSON.parse(fs.readFileSync(file,'utf8'));
    const profiles=doc.profiles||doc.players;
    if(!Array.isArray(profiles))throw Error('Invalid source profiles: '+file);
    result.push(...profiles.map(unified.normal));
  }
  return result;
}
function verifyProfiles(profiles,roster,preflight){
  if(profiles.length!==240)throw Error('Expected exactly 240 verified source profiles, got '+profiles.length);
  if(new Set(profiles.map(p=>p.id)).size!==profiles.length)throw Error('Duplicate source profile ID');
  return preflight.checkCache(profiles,roster);
}
async function runGuarded(options={},deps={}){
  const {preflight,pipeline}=deps.modules||dependencies();
  const root=options.root||path.resolve(__dirname,'..');
  const roster=(deps.loadRoster||unified.loadRoster)(root);
  const profiles=(deps.loadProfiles||sourceProfiles)(root);
  const cache=verifyProfiles(profiles,roster,preflight);
  const limit=options.limit??0,budget=options.budget??0;
  const plan=preflight.validatePlan({total:roster.length,cached:cache.valid,limit,budget,concurrency:options.concurrency??1,delayMs:options.delayMs??1200,confirmed:options.confirmed===true});
  if(budget===0&&options.key)throw Error('Never pass a Firecrawl key when budget is zero');
  if(limit>0&&!options.authorizedHttp)throw Error('HTTP pilot requires separate verified authorization');
  const result=await (deps.execute||pipeline.execute)({...options,limit,budget,key:budget>0?options.key:null},deps.pipelineDeps||{});
  if(result.transport?.firecrawlCalls>budget||result.firecrawlCalls>budget)throw Error('Paid attempts exceed authorized budget');
  if(limit===0&&(result.newlyFetched||result.transport?.firecrawlCalls||result.firecrawlCalls))throw Error('Dry-run attempted network collection');
  if(result.cached!==undefined&&result.cached<240)throw Error('Existing imported profiles missing');
  return {plan,cache,result};
}
function cliArgs(args){
  const value=(k,d)=>{const i=args.indexOf(k);if(i<0)return d;if(i+1>=args.length)throw Error('Missing '+k);return args[i+1]};
  for(const arg of args)if(!['--limit','--budget','--concurrency','--delay-ms','--output','--ack-lnr-access','--authorized-http'].includes(arg)&&!args.some((a,i)=>['--limit','--budget','--concurrency','--delay-ms','--output'].includes(a)&&args[i+1]===arg))throw Error('Unexpected argument: '+arg);
  const options={limit:Number(value('--limit','0')),budget:Number(value('--budget','0')),concurrency:Number(value('--concurrency','1')),delayMs:Number(value('--delay-ms','1200')),confirmed:args.includes('--ack-lnr-access'),authorizedHttp:args.includes('--authorized-http')};
  if(args.includes('--output'))options.dir=path.resolve(value('--output',''));
  return options;
}
if(require.main===module){Promise.resolve().then(()=>runGuarded(cliArgs(process.argv.slice(2)))).then(x=>console.log(JSON.stringify({plan:x.plan,cache:x.cache,result:{...x.result,remaining:x.result.remaining?.length}},null,2))).catch(e=>{console.error(e.message);process.exitCode=1})}
module.exports={dependencies,sourceProfiles,verifyProfiles,runGuarded,cliArgs};
