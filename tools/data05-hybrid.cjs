'use strict';
const fs=require('node:fs'),path=require('node:path');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function extract(html){
 const text=html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,' ').replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi,' ').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ');
 const name=html.match(/<h1[^>]*>([^<]+)<\/h1>/i)?.[1]?.trim()||null;
 const height=text.match(/\b([12])m(\d{2})\b/),weight=text.match(/\b(\d{2,3})\s*kg\b/),age=text.match(/\b(\d{1,2})\s*ans\b/);
 return {name,ageReported:age?+age[1]:null,heightCm:height?100*Number(height[1])+Number(height[2]):null,weightKg:weight?+weight[1]:null};
}
async function httpGet(url,{fetcher=fetch,timeout=12000}={}){
 const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),timeout);
 try{const r=await fetcher(url,{headers:{'User-Agent':'CadrageDebordementResearch/1.0','Accept':'text/html'},signal:ctrl.signal});if(!r.ok)throw Object.assign(Error('HTTP '+r.status),{status:r.status});return r.text()}finally{clearTimeout(timer)}
}
function normalizeList(list){const m=new Map();for(const p of list){if(!/^lnr:\d+$/.test(p.id)||!/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\/\d+-/.test(p.url))throw Error('Invalid player');if(m.has(p.id)&&m.get(p.id).url!==p.url)throw Error('Conflicting id');m.set(p.id,p)}return [...m.values()]}
function write(file,obj){fs.mkdirSync(path.dirname(file),{recursive:true});const tmp=file+'.tmp';fs.writeFileSync(tmp,JSON.stringify(obj,null,2));fs.renameSync(tmp,file)}
async function collect({players,dir,direct=httpGet,firecrawl=null,concurrency=2,delayMs=1000,limit=Infinity,firecrawlBudget=0,allowDirect=true}){
 if(!Number.isInteger(concurrency)||concurrency<1||concurrency>4)throw Error('concurrency 1..4');
 const list=normalizeList(players);let jobs=list.filter(p=>!fs.existsSync(path.join(dir,p.id.replace(':','-')+'.json'))).slice(0,limit),index=0,fireCalls=0,completed=0;const failures=[];
 async function worker(){while(true){const i=index++;if(i>=jobs.length)return;const p=jobs[i],file=path.join(dir,p.id.replace(':','-')+'.json');let item=null,reason='';
  if(allowDirect)try{const html=await direct(p.url),e=extract(html);if(!e.name||e.ageReported===null)throw Error('Direct page incomplete');item={...p,...e,method:'direct',birthDate:null,validAtJuly2026:false}}catch(e){reason=e.message}
  if(!item&&firecrawl&&fireCalls<firecrawlBudget){fireCalls++;try{const e=await firecrawl(p.url);if(!e?.name)throw Error('Firecrawl incomplete');item={...p,...e,method:'firecrawl',birthDate:null,validAtJuly2026:false}}catch(e){reason+=' / '+e.message}}
  if(item){write(file,item);completed++}else failures.push({id:p.id,reason:reason||'Not retrieved'});if(delayMs)await sleep(delayMs);
 }}
 await Promise.all(Array.from({length:Math.min(jobs.length,concurrency)},worker));
 const rows=fs.existsSync(dir)?fs.readdirSync(dir).filter(f=>/^lnr-\d+\.json$/.test(f)).map(f=>JSON.parse(fs.readFileSync(path.join(dir,f)))):[];const ids=new Set(rows.map(x=>x.id));if(ids.size!==rows.length)throw Error('Duplicate cache ids');
 const report={target:list.length,cached:rows.length,newlyFetched:completed,firecrawlCalls:fireCalls,failures,missing:list.filter(p=>!ids.has(p.id)).map(p=>p.id)};
 write(path.join(dir,'../profiles.json'),{players:rows});write(path.join(dir,'../report.json'),report);return report;
}
module.exports={extract,httpGet,normalizeList,collect};
