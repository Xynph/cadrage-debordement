'use strict';
// Analyse historique CI : aucune écriture GitHub, aucun effet sur les gates.
const {percentile, extractSuites, duration}=require('./ci-run-metrics.cjs');
function analyze(samples) {
 if(!Array.isArray(samples)||samples.length<2) throw Error('Au moins deux runs requis');
 const seen=new Set(), bySuite=new Map(), durations=[];
 for(const s of samples){
  if(!Number.isSafeInteger(s.id)||seen.has(s.id))throw Error('Run ID absent ou dupliqué');
  seen.add(s.id);
  if(s.name!=='Tests JavaScript'||s.status!=='completed'||s.conclusion!=='success'||!s.sha)throw Error('Run incomplet, rouge ou workflow inattendu');
  if(!Array.isArray(s.jobs)||s.jobs.length!==7||s.jobs.some(j=>j.status!=='completed'||j.conclusion!=='success'))throw Error('7 jobs SUCCESS obligatoires');
  if(s.jobs.filter(j=>/^Suites [1-5]\\/5$/.test(j.name)).length!==5)throw Error('Cinq shards obligatoires');
  const elapsed=duration(s.started_at,s.completed_at);
  if(elapsed===null)throw Error('Horodatages run invalides');
  durations.push(elapsed);
  const names=new Set();
  for(const j of s.jobs.filter(j=>/^Suites [1-5]\\/5$/.test(j.name))){
   if(typeof j.log!=='string')throw Error('Log shard manquant');
   for(const suite of extractSuites(j.log)){
    if(names.has(suite.name))throw Error('Suite dupliquée dans un run');
    names.add(suite.name);
    if(!bySuite.has(suite.name))bySuite.set(suite.name,[]);
    bySuite.get(suite.name).push(suite.seconds);
   }
  }
  if(!names.size)throw Error('Aucune durée suite extraite');
 }
 const complete=[...bySuite].filter(([,v])=>v.length===samples.length).map(([name,v])=>({name,median:percentile(v,.5),p90:percentile(v,.9),max:Math.max(...v),samples:v.length})).sort((a,b)=>b.p90-a.p90||b.median-a.median||a.name.localeCompare(b.name));
 return {runs:samples.length,medianCI:percentile(durations,.5),p90CI:percentile(durations,.9),minCI:Math.min(...durations),maxCI:Math.max(...durations),completeSuites:complete.length,partialSuites:bySuite.size-complete.length,slowest:complete.slice(0,20)};
}
function report(a){return ['# Historique CI — '+a.runs+' runs SUCCESS','','Durée CI : médiane '+a.medianCI+' s ; P90 '+a.p90CI+' s ; plage '+a.minCI+'–'+a.maxCI+' s.','Suites présentes dans tous les runs : '+a.completeSuites+' ; suites non comparables : '+a.partialSuites+'.','','| Suite | Médiane (s) | P90 (s) | Maximum (s) |','|---|---:|---:|---:|',...a.slowest.map(x=>'| '+x.name+' | '+x.median+' | '+x.p90+' | '+x.max+' |'),'','Mesures descriptives : ne prouvent pas une accélération causale. Les suites absentes d’un run sont exclues du classement.'].join('\\n');}
async function get(url,token,raw=false){
 const r=await fetch(url,{headers:{Accept:'application/vnd.github+json',Authorization:'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'}});
 if(!r.ok)throw Error('API GitHub '+r.status);return raw?r.text():r.json();
}
async function read(id,token){
 const base='https://api.github.com/repos/Xynph/cadrage-debordement/actions';
 const [r,page]=await Promise.all([get(base+'/runs/'+id,token),get(base+'/runs/'+id+'/jobs?per_page=100',token)]);
 if(page.total_count!==7||page.jobs.length!==7)throw Error('Pagination ou nombre de jobs invalide');
 const jobs=await Promise.all(page.jobs.map(async j=>({name:j.name,status:j.status,conclusion:j.conclusion,log:/^Suites [1-5]\\/5$/.test(j.name)?await get(base+'/jobs/'+j.id+'/logs',token,true):''})));
 return {id:r.id,name:r.name,status:r.status,conclusion:r.conclusion,sha:r.head_sha,started_at:r.run_started_at||r.created_at,completed_at:r.updated_at,jobs};
}
async function main(){
 const ids=process.argv.slice(2),token=process.env.GH_TOKEN;
 if(ids.length<2||ids.length>30||ids.some(id=>!/^\\d+$/.test(id))||!token)throw Error('Usage : GH_TOKEN=... node ci/ci-history-metrics.cjs RUN1 RUN2 ... (2 à 30)');
 const samples=await Promise.all(ids.map(id=>read(id,token))),out=report(analyze(samples));console.log(out);
 if(process.env.GITHUB_STEP_SUMMARY)require('node:fs').appendFileSync(process.env.GITHUB_STEP_SUMMARY,out+'\\n');
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={analyze,report};
