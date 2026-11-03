'use strict';
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {execute}=require('./chat-release.cjs');
const REPO='Xynph/cadrage-debordement',OWNER=350229047,SHA=/^[a-f0-9]{40}$/;
const TRIGGERS=['Tests JavaScript','UI Chromium mutualise - CI V3','Carrieres multi-clubs - validation native','IA adverse - audit 24 matchs natifs','V60 relations presse hors match','V61 calendrier conseil et objectifs'];
const JOBS=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
function need(v,s){if(!v)throw Error(s);}
function validateTrigger(e,env){
 need(env.GITHUB_EVENT_NAME==='workflow_run'&&env.GITHUB_REPOSITORY===REPO,'Bad trigger or repository');
 need(env.CD_AUTO_RELEASE_ENABLED==='true','Feature flag disabled');
 need(e.action==='completed'&&e.repository?.full_name===REPO,'Bad event');
 const r=e.workflow_run;
 need(r&&TRIGGERS.includes(r.name)&&r.event==='pull_request'&&r.status==='completed'&&r.conclusion==='success','Not a successful PR CI');
 need(SHA.test(r.head_sha)&&Number.isSafeInteger(r.id),'Bad workflow SHA or ID');
 need(Array.isArray(r.pull_requests)&&r.pull_requests.length===1,'No unique PR');
 const pr=r.pull_requests[0].number;need(Number.isSafeInteger(pr)&&pr>0,'Bad PR number');
 need(SHA.test(env.GITHUB_SHA),'Bad pinned main SHA');
 return {pr,head:r.head_sha,runId:r.id,sourceName:r.name,main:env.GITHUB_SHA};
}
function safePath(f){
 const p=f.filename||'';
 if(!['added','modified'].includes(f.status)||p.includes('..'))return false;
 return /^docs\/[a-zA-Z0-9_./-]+\.md$/.test(p)
 || /^tests\/[a-zA-Z0-9_-]+\.cjs$/.test(p)
 || /^dist\/[a-zA-Z0-9_-]+\.css$/.test(p)
 || /^dist\/(?:ui[0-9]+|v[0-9]+)-[a-zA-Z0-9_-]+\.js$/.test(p);
}
function validateCandidate(p,files,head,main){
 need(p?.state==='open'&&!p.draft&&p.base?.ref==='main'&&p.base.sha===main,'Base main mismatch/draft');
 need(p.head?.sha===head&&p.head.repo?.full_name===REPO,'Head mismatch or fork');
 need(p.user?.id===OWNER&&p.user.login==='Xynph'&&p.user.type==='User','Not owner-created');
 need(p.mergeable===true&&p.mergeable_state==='clean','PR not mergeable');
 need(Array.isArray(files)&&files.length>0&&files.length<=12&&files.length===p.changed_files,'Incomplete/excessive diff');
 need(files.every(safePath),'Unsafe file');
 if(files.some(f=>f.filename.startsWith('dist/')&&f.filename.endsWith('.js')))
  need(files.some(f=>f.filename.startsWith('tests/')&&f.filename.endsWith('.cjs')),'JS without test');
 return true;
}
function checkReservations(prNumber,files,otherPRs,fetchFiles){
 need(Array.isArray(otherPRs)&&otherPRs.length<100,'Open PR list incomplete');
 const own=new Set(files.map(f=>f.filename));
 for(const p of otherPRs){
  if(p.number===prNumber||p.state!=='open')continue;
  const changed=fetchFiles(p.number);
  need(Array.isArray(changed)&&changed.length<100,'Other PR diff incomplete');
  need(!changed.some(f=>own.has(f.filename)),'Conflicting concurrent PR #'+p.number);
 }
 return true;
}
function requiredWorkflows(files){
 const required=['Tests JavaScript','V60 relations presse hors match','V61 calendrier conseil et objectifs'];
 if(files.some(f=>f.filename.startsWith('dist/')))required.push('UI Chromium mutualise - CI V3');
 return required;
}
function latestRuns(runs,head,trigger,required){
 need(Array.isArray(runs)&&runs.length>0&&runs.length<100,'Missing/ambiguous CI runs');
 need(Array.isArray(required)&&required.length>=3,'Required workflow policy missing');
 const latest=new Map();
 for(const r of runs.filter(r=>r.head_sha===head&&r.event==='pull_request'))
  if(!latest.has(r.name)||r.id>latest.get(r.name).id)latest.set(r.name,r);
 need(latest.get('Tests JavaScript')?.id===trigger,'Stale JS run');
 for(const name of required)need(latest.has(name),'Required PR workflow absent: '+name);
 for(const r of latest.values())need(r.status==='completed'&&r.conclusion==='success','Pending/failing PR CI '+r.name);
 return true;
}
function api(url,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+url];
 if(body)args.push('--input','-');
 const out=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000,maxBuffer:8*1024*1024});
 return out.trim()?JSON.parse(out):null;
}
function runGate(pr,expected,merge){
 try{return execFileSync(process.execPath,[path.join(__dirname,'release-gate.cjs'),String(pr),...(merge?['--merge']:[])],
 {encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,env:{...process.env,CD_REPO:REPO,CD_EXPECTED_HEAD_SHA:expected}});}
 catch(e){throw Error('Official gate rejected: '+String(e.stdout||'').slice(0,2000)+' '+String(e.stderr||'').slice(0,1000));}
}
async function runAuto(event,env,services={}){
 const t=validateTrigger(event,env),req=services.api||api;
 need(req('git/ref/heads/main').object.sha===t.main,'Main changed');
 const pr=req('pulls/'+t.pr),files=req('pulls/'+t.pr+'/files?per_page=100');
 validateCandidate(pr,files,t.head,t.main);
 checkReservations(t.pr,files,req('pulls?state=open&per_page=100'),n=>req('pulls/'+n+'/files?per_page=100'));
 const wf=req('actions/workflows/tests.yml');need(wf.state==='active','Required workflow inactive');
 const source=req('actions/runs/'+t.runId);
 need(source.name===t.sourceName&&source.head_sha===t.head&&source.event==='pull_request'&&source.status==='completed'&&source.conclusion==='success','Unexpected source CI');
 const runs=req('actions/runs?event=pull_request&head_sha='+t.head+'&per_page=100').workflow_runs;
 const js=runs.filter(r=>r.name==='Tests JavaScript'&&r.head_sha===t.head).sort((x,y)=>y.id-x.id)[0];
 need(js&&js.workflow_id===wf.id,'Required JS CI missing');
 const jobs=req('actions/runs/'+js.id+'/jobs?per_page=100').jobs;
 need(jobs.length===7&&JOBS.every(n=>jobs.filter(j=>j.name===n&&j.status==='completed'&&j.conclusion==='success').length===1),'Missing seven green PR jobs');
 latestRuns(runs,t.head,js.id,requiredWorkflows(files));
 need(runs.filter(r=>r.name===source.name).sort((x,y)=>y.id-x.id)[0]?.id===source.id,'Stale source run');
 need(req('git/ref/heads/main').object.sha===t.main,'Main moved before gate');
 return (services.execute||execute)({pr:t.pr,expected:t.head,mode:'merge'}, {}, {
  api:req,snapshot:t.main,autoAuthorized:true,
  sleep:services.sleep||((ms)=>new Promise(resolve=>setTimeout(resolve,ms))),
  execGate:services.execGate||runGate,
  watch:services.watch||((id)=>execFileSync('gh',['run','watch',String(id),'--repo',REPO,'--interval','30','--exit-status'],{stdio:'inherit',timeout:32*60*1000}))
 });
}
async function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 try{const result=await runAuto(event,process.env);fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'Auto-release verified '+JSON.stringify(result)+'\n');}
 catch(e){fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'Auto-release STOP: '+e.message+'\n');throw e;}
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={validateTrigger,safePath,validateCandidate,checkReservations,requiredWorkflows,latestRuns,runAuto};
