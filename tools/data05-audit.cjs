'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {loadRoster,run}=require('./data05-unified.cjs');
const TYPES=[['data05-bulk','profiles'],['data05-bulk2','players'],['data05-bulk3','players']];
function audit(root=path.resolve(__dirname,'..')){
 const list=loadRoster(root),index=new Map(list.map(p=>[p.id,p]));const ids=new Set(),errors=[],counts={};
 for(const [dirname,key] of TYPES){
  counts[dirname]=0;
  for(let n=1;n<=5;n++){
   const file=path.join(root,'modding',dirname,'profiles-'+String(n).padStart(2,'0')+'.json');
   const batch=JSON.parse(fs.readFileSync(file,'utf8'))[key];
   if(!Array.isArray(batch))throw Error('Invalid batch '+file);
   for(const p of batch){
    const ref=index.get(p.id),url=p.url||p.sourceUrl;
    if(!ref||ref.url!==url||ref.club!==p.club)errors.push('Mismatch '+p.id);
    if(ids.has(p.id))errors.push('Duplicate '+p.id);
    ids.add(p.id);counts[dirname]++;
   }
  }
 }
 if(errors.length)throw Error(errors.join('; '));
 if(ids.size!==240||list.length!==1592)throw Error('Unexpected totals');
 return {catalogue:list.length,uniqueImportedCandidates:ids.size,remaining:list.length-ids.size,counts};
}
async function dryRun(root=path.resolve(__dirname,'..')){
 const result=audit(root),tmp=fs.mkdtempSync(path.join(os.tmpdir(),'data05-audit-'));
 try{
  const report=await run({root,dir:tmp,limit:0,budget:0,concurrency:1,delayMs:0});
  if(report.cached!==240||report.imported!==240||report.firecrawlCalls!==0||report.newlyFetched!==0)throw Error('Dry-run import mismatch: '+JSON.stringify(report));
  return {...result,dryRunImported:report.imported,dryRunApiCalls:report.firecrawlCalls,exported:JSON.parse(fs.readFileSync(path.join(tmp,'players.json'))).players.length};
 }finally{fs.rmSync(tmp,{recursive:true,force:true})}
}
if(require.main===module)dryRun().then(x=>console.log(JSON.stringify(x,null,2))).catch(e=>{console.error(e.stack);process.exitCode=1});
module.exports={audit,dryRun};
