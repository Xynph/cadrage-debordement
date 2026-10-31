'use strict';
const fs=require('node:fs'),path=require('node:path');
const {setTimeout:pause}=require('node:timers/promises');
const ROOT=path.resolve(__dirname,'..');
const rosterFiles=['top14-a','top14-b','prod2-a','prod2-b'];
function loadRoster(root=ROOT){
 const clubs=rosterFiles.flatMap(n=>require(path.join(root,'modding/data03',n+'.json')).clubs);
 const list=clubs.flatMap(c=>c.players.map(p=>({id:p.id,club:c.club,url:p.url})));
 if(clubs.length!==30||list.length!==1592||new Set(list.map(p=>p.id)).size!==1592)throw Error('Expected 30 clubs and 1592 unique LNR IDs');
 return list;
}
function atomic(file,obj){fs.mkdirSync(path.dirname(file),{recursive:true});const tmp=file+'.tmp-'+process.pid;fs.writeFileSync(tmp,JSON.stringify(obj,null,2)+'\n');fs.renameSync(tmp,file)}
function normal(p){
 const h=p.heightCm??(typeof p.height==='string'&&/^[12]m\d{2}$/.test(p.height)?Number(p.height.replace('m','')):null);
 return {id:p.id,club:p.club,url:p.url||p.sourceUrl,name:p.returnedName||p.name||null,position:p.positionGroup||p.position||null,nationality:p.nationality||null,age:p.ageReported??p.age??null,heightCm:h,weightKg:p.weightKg??null,birthDate:null,validAtJuly1:false,origin:'verified-lnr-snapshot'};
}
function importExisting({root=ROOT,cache,roster,strict=true}){
 const known=new Map(roster.map(x=>[x.id,x]));let imported=0,invalid=[];
 const collections=[['modding/data05-bulk','profiles-',5,'profiles'],['modding/data05-bulk2','profiles-',5,'players'],['modding/data05-bulk3','profiles-',5,'players']];
 for(const [dir,prefix,count,key] of collections)for(let n=1;n<=count;n++){
  const file=path.join(root,dir,prefix+String(n).padStart(2,'0')+'.json');
  if(!fs.existsSync(file)){if(strict)throw Error('Missing input '+file);continue}
  for(const old of JSON.parse(fs.readFileSync(file))[key]){
   const p=normal(old),ref=known.get(p.id);
   if(!ref||ref.url!==p.url||ref.club!==p.club||!p.name){invalid.push(p.id);continue}
   const target=path.join(cache,p.id.replace(':','-')+'.json');
   if(!fs.existsSync(target)){atomic(target,p);imported++}
  }
 }
 if(invalid.length)throw Error('Existing cache mismatches '+invalid.join(','));
 return {imported};
}
function parseHtml(html){
 const title=html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)?.[1]?.replace(/<[^>]*>/g,'').trim()||null;
 const text=html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,' ').replace(/<[^>]*>/g,' ').replace(/\s+/g,' ');
 const ht=text.match(/\b([12])m(\d{2})\b/),wt=text.match(/\b(\d{2,3})\s*kg\b/),age=text.match(/\b(\d{1,2})\s*ans\b/);
 return {name:title,age:age?+age[1]:null,heightCm:ht?100*(+ht[1])+(+ht[2]):null,weightKg:wt?+wt[1]:null};
}
async function direct(url){
 const control=new AbortController(),timer=setTimeout(()=>control.abort(),18000);
 try{const r=await fetch(url,{signal:control.signal,headers:{'User-Agent':'CadrageDebordementResearch/1.0'}});if(!r.ok)throw Object.assign(Error('LNR HTTP '+r.status),{status:r.status});return parseHtml(await r.text())}finally{clearTimeout(timer)}
}
function parseMarkdown(s){
 const m=(re)=>s.match(re)?.[1]||null,h=m(/\b([12]m\d{2})\b/),w=m(/\b(\d{2,3}) kg\b/),a=m(/\b(\d{1,2}) ans\b/);
 return {name:m(/^# (.+)$/m),position:m(/\]\(https:\/\/(?:top14|prod2)\.lnr\.fr\/club\/[^)]*\)\s+([^\n]+)/),nationality:m(/\b\d{1,2} ans\s*\n(?:!\[[^\]]*\]\([^)]+\)\s*)?([^\n]+)\n/),age:a?+a:null,heightCm:h?+h.replace('m',''):null,weightKg:w?+w:null};
}
async function firecrawl(url,key){
 if(!key)throw Error('FIRECRAWL_API_KEY required');
 const r=await fetch('https://api.firecrawl.dev/v2/scrape',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({url,formats:['markdown']})});
 if(!r.ok)throw Object.assign(Error('Firecrawl HTTP '+r.status),{status:r.status});
 const data=await r.json();if(!data.success||!data.data?.markdown)throw Error('Firecrawl empty response');
 return parseMarkdown(data.data.markdown);
}
async function run({root=ROOT,dir=path.join(root,'modding/data05-unified-output'),list=loadRoster(root),http=direct,fallback=firecrawl,key=process.env.FIRECRAWL_API_KEY,budget=0,limit=1592,concurrency=2,delayMs=1000,importCache=true}={}){
 if(!Number.isInteger(budget)||budget<0||!Number.isInteger(limit)||limit<0||!Number.isInteger(concurrency)||concurrency<1||concurrency>4)throw Error('Invalid limits');
 const cache=path.join(dir,'cache');fs.mkdirSync(cache,{recursive:true});
 const imported=importCache?importExisting({root,cache,roster:list}):{imported:0};
 const pending=list.filter(p=>!fs.existsSync(path.join(cache,p.id.replace(':','-')+'.json'))).slice(0,limit);
 let idx=0,calls=0,completed=0;const errors=[];
 async function worker(){while(true){const i=idx++;if(i>=pending.length)break;const p=pending[i];let data=null,reason=null;
  try{data=await http(p.url)}catch(e){reason=e.message}
  if((!data?.name||!data?.age)&&fallback&&key&&calls<budget){calls++;try{data=await fallback(p.url,key)}catch(e){reason=e.message}}
  if(data?.name&&data?.age){atomic(path.join(cache,p.id.replace(':','-')+'.json'),{...normal({...p,...data}),origin:'live-lnr-snapshot'});completed++}
  else errors.push({id:p.id,reason:reason||'missing-fields'});
  if(delayMs)await pause(delayMs);
 }}
 await Promise.all(Array.from({length:Math.min(concurrency,pending.length)},worker));
 const entries=fs.readdirSync(cache).filter(n=>/^lnr-\d+\.json$/.test(n)).map(n=>JSON.parse(fs.readFileSync(path.join(cache,n))));
 const ids=new Set(entries.map(p=>p.id));if(ids.size!==entries.length)throw Error('Duplicate cache');
 const report={target:list.length,cached:entries.length,imported:imported.imported,newlyFetched:completed,firecrawlCalls:calls,errors,remaining:list.filter(x=>!ids.has(x.id)).map(x=>x.id)};
 atomic(path.join(dir,'players.json'),{dateScope:'collection-time-not-2026-07-01',players:entries});atomic(path.join(dir,'report.json'),report);
 return report;
}
if(require.main===module){const args=process.argv.slice(2),arg=(name,defaultValue)=>{const i=args.indexOf(name);return i<0?defaultValue:args[i+1]};
 run({budget:Number(arg('--budget','0')),limit:Number(arg('--limit','10')),concurrency:Number(arg('--concurrency','2')),delayMs:Number(arg('--delay-ms','1000')),dir:path.resolve(arg('--output','modding/data05-unified-output'))}).then(r=>{console.log(JSON.stringify({...r,remaining:r.remaining.length},null,2));if(r.errors.length)process.exitCode=1}).catch(e=>{console.error(e.stack);process.exitCode=1});
}
module.exports={loadRoster,normal,importExisting,parseHtml,parseMarkdown,run};
