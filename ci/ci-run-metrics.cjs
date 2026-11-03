'use strict';
// Métriques CI en lecture seule, sur deux runs verts du même workflow.
const fs=require('node:fs');
function percentile(values,q){if(!values.length||values.some(x=>!Number.isFinite(x)||x<0))return null;const s=[...values].sort((a,b)=>a-b);return s[Math.max(0,Math.ceil(q*s.length)-1)];}
function duration(a,b){const x=Date.parse(a),y=Date.parse(b);return Number.isFinite(x)&&Number.isFinite(y)&&y>=x?(y-x)/1000:null;}
function extractSuites(log){return [...String(log).matchAll(/\bPASS (tests\/[A-Za-z0-9._-]+\.cjs) \((\d+) s\)/g)].map(m=>({name:m[1],seconds:Number(m[2])}));}
function summarize(run,jobs,logs={}){
 if(run.status!=='completed'||run.conclusion!=='success'||run.name!=='Tests JavaScript')throw Error('Run non terminal, rouge ou workflow inattendu');
 if(!jobs.length||jobs.some(j=>j.status!=='completed'||j.conclusion!=='success'))throw Error('Job non terminal ou rouge');
 const shards=jobs.filter(j=>/^Suites [1-5]\/5$/.test(j.name));
 if(shards.length!==5||jobs.length!==7)throw Error('Les 7 jobs sont obligatoires');
 const times=jobs.map(j=>duration(j.started_at,j.completed_at));
 if(times.some(x=>x===null))throw Error('Horodatages incomplets');
 const shardTimes=shards.map(j=>duration(j.started_at,j.completed_at));
 const suites=shards.flatMap(j=>extractSuites(logs[j.id]||''));
 return {run:run.id,sha:run.head_sha,wallSeconds:duration(run.run_started_at||run.created_at,run.updated_at),runnerSeconds:times.reduce((a,b)=>a+b,0),shardPeakSeconds:Math.max(...shardTimes),shardP90Seconds:percentile(shardTimes,.9),suiteCount:suites.length,suiteP90Seconds:percentile(suites.map(x=>x.seconds),.9)};
}
function delta(b,a,k){return b[k]===null||a[k]===null||!b[k]?null:Math.round((a[k]-b[k])*1000/b[k])/10;}
function report(b,a){
 const rows=[['Durée CI (s)','wallSeconds'],['Somme durées jobs (s)','runnerSeconds'],['Shard critique (s)','shardPeakSeconds'],['P90 des shards (s)','shardP90Seconds'],['P90 par suite (s)','suiteP90Seconds']];
 return ['# Mesure GitHub Actions — avant/après','','Run avant #'+b.run+' ; après #'+a.run+'.','','| Mesure | Avant | Après | Variation |','|---|---:|---:|---:|',...rows.map(([label,key])=>{const p=delta(b,a,key);return '| '+label+' | '+(b[key]??'N/D')+' | '+(a[key]??'N/D')+' | '+(p===null?'N/D':p+' %')+' |';}),'','Suites extraites des logs : '+b.suiteCount+' avant, '+a.suiteCount+' après.','Deux exécutions ne prouvent pas un gain causal ; comparer des workloads équivalents.'].join('\n');
}
async function get(path,token,raw=false){
 const response=await fetch('https://api.github.com/repos/Xynph/cadrage-debordement'+path,{headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'},redirect:'follow'});
 if(!response.ok)throw Error('Erreur API GitHub '+response.status+' : '+path);
 return raw?response.text():response.json();
}
async function read(id,token){
 const [run,page]=await Promise.all([get('/actions/runs/'+id,token),get('/actions/runs/'+id+'/jobs?per_page=100',token)]);
 if(page.total_count>page.jobs.length)throw Error('Pagination incomplète : refus');
 const logs={};
 for(const job of page.jobs.filter(j=>/^Suites [1-5]\/5$/.test(j.name)))logs[job.id]=await get('/actions/jobs/'+job.id+'/logs',token,true);
 return summarize(run,page.jobs,logs);
}
async function main(){
 const [before,after]=process.argv.slice(2),token=process.env.GH_TOKEN;
 if(!/^\d+$/.test(before||'')||!/^\d+$/.test(after||'')||!token)throw Error('Usage: GH_TOKEN=... node ci/ci-run-metrics.cjs <run-avant> <run-après>');
 const [b,a]=await Promise.all([read(before,token),read(after,token)]);
 const output=report(b,a);console.log(output);
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,output+'\n');
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={percentile,duration,extractSuites,summarize,delta,report};
