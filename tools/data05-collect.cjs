'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const https=require('node:https');
const {setTimeout:delay}=require('node:timers/promises');
function parseProfile(markdown,url,id,club,collectedAt){
  const h=markdown.slice(0,1600),one=r=>(h.match(r)||[])[1]||null;
  const name=one(/^# (.+)$/m);
  const position=one(/\]\(https:\/\/(?:top14|prod2)\.lnr\.fr\/club\/[^)]*\)\s+([^\n]+)/);
  const height=one(/\b([12]m\d{2})\b), weight=one(/\b(\d{2,3}) kg\b/),age=one(/\b(\d{1,2}) ans\b/);
  const nationality=one(/\b\d{1,2} ans\s*\n(?:!\[[^\]]*\]\([^)]+\)\s*)?([^\n]+)\n/);
  if(!name||!position||!age||!nationality)throw Error('Missing required profile fields: '+id);
  return {id,club,name,profileUrl:url,positionGroup:position.trim(),nationality:nationality.trim(),ageAtCollection:Number(age),heightCm:height?Number(height.replace('m','')):null,weightKg:weight?Number(weight):null,dateOfBirth:null,careerStartMembership:'unverified',collectedAt};
}
function inputs(inputDir){
  const clubs=['top14-a','top14-b','prod2-a','prod2-b'].flatMap(n=>JSON.parse(fs.readFileSync(path.join(inputDir,n+'.json'))).clubs);
  if(clubs.length!==30)throw Error('Expected 30 clubs, got '+clubs.length);
  const players=clubs.flatMap(c=>c.players.map(p=>({id:p.id,club:c.club,url:p.url})));
  if(players.length!==1592||new Set(players.map(p=>p.id)).size!==1592)throw Error('Expected 1592 distinct LNR ids');
  for(const p of players)if(!/^lnr:\d+$/.test(p.id)||!/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\/\d+-/.test(p.url))throw Error('Invalid source '+p.id);
  return players;
}
function atomicJson(file,object){fs.mkdirSync(path.dirname(file),{recursive:true});const tmp=file+'.tmp-'+process.pid;fs.writeFileSync(tmp,JSON.stringify(object,null,2)+'\n');fs.renameSync(tmp,file)}
function request(url,body,key){
  return new Promise((resolve,reject)=>{
    const raw=JSON.stringify(body);const u=new URL(url);
    const req=https.request(u,{method:'POST',headers:{'Authorization':'Bearer '+key,'Content-Type':'application/json','Content-Length':Buffer.byteLength(raw)},timeout:25000},res=>{
      let s='';res.on('data',d=>s+=d);res.on('end',()=>{let data;try{data=JSON.parse(s)}catch{return reject(Error('Invalid JSON response'))}if(res.statusCode>=400||!data.success)return reject(Object.assign(Error('Firecrawl HTTP '+res.statusCode),{status:res.statusCode}));resolve(data)});
    });req.on('timeout',()=>req.destroy(Error('Timeout')));req.on('error',reject);req.end(raw);
  });
}
async function run({list,outputDir,key,concurrency=4,limit=Infinity,maxCalls=Infinity,scrape=request,retries=2,sleep=delay}){
  if(!key)throw Error('FIRECRAWL_API_KEY is required');
  if(!Number.isInteger(concurrency)||concurrency<1||concurrency>8)throw Error('Concurrency must be 1..8');
  fs.mkdirSync(outputDir,{recursive:true});const cacheDir=path.join(outputDir,'cache');fs.mkdirSync(cacheDir,{recursive:true});
  const unique=new Map();for(const p of list){if(unique.has(p.id)&&unique.get(p.id).url!==p.url)throw Error('Conflicting player id '+p.id);unique.set(p.id,p)}
  const pending=[...unique.values()].filter(p=>!fs.existsSync(path.join(cacheDir,p.id.replace(':','-')+'.json'))).slice(0,limit);
  let index=0,calls=0,ok=0,errors=[];
  async function worker(){
    while(true){
      const k=index++;if(k>=pending.length)return;
      const p=pending[k],file=path.join(cacheDir,p.id.replace(':','-')+'.json');
      let last;
      for(let attempt=0;attempt<=retries;attempt++){
        if(calls>=maxCalls)break;
        calls++;
        try{
          const res=await scrape('https://api.firecrawl.dev/v2/scrape',{url:p.url,formats:['markdown']},key);
          if(!res.data?.markdown)throw Error('Empty markdown');
          const row=parseProfile(res.data.markdown,p.url,p.id,p.club,new Date().toISOString());
          atomicJson(file,row);ok++;last=null;break;
        }catch(e){last=e;if([401,402,403].includes(e.status))break;if(attempt<retries)await sleep(150*(2**attempt));}
      }
      if(last)errors.push({id:p.id,error:String(last.message||last)});
    }
  }
  await Promise.all(Array.from({length:Math.min(concurrency,pending.length)},worker));
  const rows=fs.readdirSync(cacheDir).filter(f=>/^lnr-\d+\.json$/.test(f)).map(f=>JSON.parse(fs.readFileSync(path.join(cacheDir,f)))).filter(p=>unique.has(p.id));
  const verified=new Map(rows.map(p=>[p.id,p]));if(verified.size!==rows.length)throw Error('Duplicate cached ids');
  const report={sourceCount:unique.size,cached:rows.length,processedNow:ok,apiCalls:calls,missing:[...unique.keys()].filter(id=>!verified.has(id)),errors};
  atomicJson(path.join(outputDir,'profiles.json'),{snapshot:'collection-time',players:rows});
  atomicJson(path.join(outputDir,'report.json'),report);
  return report;
}
if(require.main===module){
  (async()=>{
    const args=process.argv.slice(2),get=(k,d)=>args.includes(k)?args[args.indexOf(k)+1]:d;
    const list=inputs(path.resolve(get('--input','modding/data03')));
    const report=await run({list,outputDir:path.resolve(get('--output','modding/data05-collector/results')),key:process.env.FIRECRAWL_API_KEY,concurrency:Number(get('--concurrency','4')),limit:Number(get('--limit','1592')),maxCalls:Number(get('--budget','700'))});
    console.log(JSON.stringify({...report,missing:report.missing.length},null,2));if(report.errors.length)process.exitCode=1;
  })().catch(e=>{console.error(e.message);process.exitCode=1});
}
module.exports={parseProfile,inputs,run};
