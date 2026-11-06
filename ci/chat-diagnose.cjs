'use strict';
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const REPO = 'Xynph/cadrage-debordement';
const OWNER_ID = 350229047;
const REPO_ID = 1439603196;
const RULESET = 26326518;
const JOBS = ['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
function assert(ok,msg) { if (!ok) throw Error(msg); }
function validate(event,env) {
  assert(env.GITHUB_EVENT_NAME==='issue_comment'&&env.GITHUB_REPOSITORY===REPO&&env.GITHUB_ACTOR==='Xynph'&&env.GITHUB_TRIGGERING_ACTOR==='Xynph','Acteur ou événement non autorisé');
  assert(event.action==='created'&&event.repository?.id===REPO_ID&&event.repository?.full_name===REPO&&event.issue?.number===73&&!event.issue.pull_request,'Dépôt ou issue incorrect');
  assert(event.sender?.id===OWNER_ID&&event.sender?.login==='Xynph'&&event.comment?.user?.id===OWNER_ID&&event.comment?.user?.login==='Xynph'&&event.comment?.user?.type==='User','Auteur non autorisé');
  const match=/^\/cd-diagnose ([1-9][0-9]*) ([0-9a-f]{40})$/.exec(event.comment?.body||'');
  assert(match&&Number.isSafeInteger(Number(match[1]))&&Number.isSafeInteger(event.comment.id),'Commande stricte attendue : /cd-diagnose PR HEAD');
  return {number:Number(match[1]),expected:match[2],commentId:event.comment.id};
}
function api(endpoint,method='GET',body) {
  const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+endpoint];
  if(body)args.push('--input','-');
  const output=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000,maxBuffer:8*1024*1024});
  return output.trim()?JSON.parse(output):null;
}
function pages(endpoint,key,max=10) {
  const out=[];
  for(let page=1;page<=max;page++) {
    const separator=endpoint.includes('?')?'&':'?';
    const response=api(endpoint+separator+'per_page=100&page='+page);
    const part=Array.isArray(response)?response:response?.[key];
    assert(Array.isArray(part),'Pagination API invalide : '+endpoint);
    out.push(...part);
    if(part.length<100)return out;
  }
  throw Error('Trop de pages : '+endpoint);
}
function completedSeven(jobs) {
  return jobs.length===7&&JOBS.every(name=>jobs.filter(j=>j.name===name&&j.status==='completed'&&j.conclusion==='success').length===1);
}
function latestRun(runs,sha,workflowId,events) {
  return runs.filter(r=>r.workflow_id===workflowId&&r.head_sha===sha&&r.head_branch==='main'&&events.includes(r.event)).sort((a,b)=>b.id-a.id)[0];
}
function rulesetStatus(r) {
  const list=r.rules||[];
  const status=list.find(x=>x.type==='required_status_checks');
  const required=status?.parameters?.required_status_checks||[];
  const includes=r.conditions?.ref_name?.include||[];
  const mainTargeted=includes.some(x=>['refs/heads/main','~DEFAULT_BRANCH','~ALL'].includes(x));
  return mainTargeted&&r.id===RULESET&&r.enforcement==='active'&&Array.isArray(r.bypass_actors)&&r.bypass_actors.length===0&&
    list.some(x=>x.type==='pull_request')&&list.some(x=>x.type==='deletion')&&list.some(x=>x.type==='non_fast_forward')&&
    status?.parameters?.strict_required_status_checks_policy===true&&
    required.some(x=>x.context==='Validation CI'&&x.integration_id===15368);
}
function diagnose(cmd) {
  const original=api('issues/comments/'+cmd.commentId);
  assert(original.user?.id===OWNER_ID&&original.body==='/cd-diagnose '+cmd.number+' '+cmd.expected&&original.issue_url==='https://api.github.com/repos/'+REPO+'/issues/73','Commande modifiée ou déplacée');
  const main=api('git/ref/heads/main').object.sha;
  const pr=api('pulls/'+cmd.number);
  assert(pr.head?.sha===cmd.expected&&pr.base?.ref==='main'&&pr.base?.sha===main,'PR / HEAD / main différents de la commande');
  assert(pr.head?.repo?.full_name===REPO,'Dépôt de PR externe refusé');
  const ruleset=api('rulesets/'+RULESET);
  const validRuleset=rulesetStatus(ruleset);
  const workflow=api('actions/workflows/tests.yml');
  assert(workflow.state==='active','Workflow Tests JavaScript inactif');
  const runs=pages('actions/workflows/tests.yml/runs?branch=main&head_sha='+main,'workflow_runs');
  const run=latestRun(runs,main,workflow.id,['push','workflow_dispatch']);
  const mainJobs=run?pages('actions/runs/'+run.id+'/jobs','jobs'):[];
  const mainCI=!!run&&run.status==='completed'&&run.conclusion==='success'&&completedSeven(mainJobs);
  const prRuns=pages('actions/workflows/tests.yml/runs?event=pull_request&head_sha='+cmd.expected,'workflow_runs');
  const prRun=prRuns.filter(x=>x.head_sha===cmd.expected&&x.event==='pull_request'&&x.name==='Tests JavaScript').sort((a,b)=>b.id-a.id)[0];
  const prJobs=prRun?pages('actions/runs/'+prRun.id+'/jobs','jobs'):[];
  const prCI=!!prRun&&prRun.status==='completed'&&prRun.conclusion==='success'&&completedSeven(prJobs);
  const checks=pages('commits/'+cmd.expected+'/check-runs','check_runs');
  const required=ruleset.rules.find(x=>x.type==='required_status_checks')?.parameters?.required_status_checks||[];
  const missing=required.filter(x=>!checks.some(c=>c.name===x.context&&c.status==='completed'&&c.conclusion==='success'&&(!x.integration_id||c.app?.id===x.integration_id))).map(x=>x.context);
  const valid=validRuleset&&mainCI&&prCI&&missing.length===0&&pr.state==='open'&&!pr.draft&&pr.mergeable===true&&pr.mergeable_state==='clean';
  return {valid,pr:cmd.number,head:cmd.expected,main,mergeable:pr.mergeable,mergeable_state:pr.mergeable_state,ready:!pr.draft,ruleset:validRuleset,mainCI,mainRun:run?.id,prCI,prRun:prRun?.id,missing};
}
function format(result,error,runUrl) {
  if(error)return 'DIAGNOSTIC IMPOSSIBLE — STOP (aucune fusion). Erreur : '+String(error.message).slice(0,500)+'\nRun : '+runUrl;
  return [
    result.valid?'DIAGNOSTIC VERT — prérequis observés, AUCUNE FUSION':'DIAGNOSTIC STOP — prérequis incomplets, AUCUNE FUSION',
    'PR #'+result.pr+' HEAD '+result.head,
    'main '+result.main,
    'READY='+result.ready+' mergeable='+result.mergeable+' mergeable_state='+result.mergeable_state,
    'ruleset #'+RULESET+' vérifié='+result.ruleset,
    'main Tests JavaScript 7/7='+result.mainCI+' (run '+(result.mainRun||'absent')+')',
    'PR Tests JavaScript 7/7='+result.prCI+' (run '+(result.prRun||'absent')+')',
    'Checks requis manquants/non SUCCESS='+JSON.stringify(result.missing),
    'Ce diagnostic n’autorise pas à contourner /cd-check puis /cd-merge ni à fusionner une tête différente.',
    'Run : '+runUrl
  ].join('\n');
}
async function main() {
  const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
  const cmd=validate(event,process.env);
  let result,error;
  try {result=diagnose(cmd);} catch(e) {error=e;}
  const runUrl='https://github.com/'+REPO+'/actions/runs/'+process.env.GITHUB_RUN_ID;
  const report=format(result,error,runUrl);
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,report+'\n');
  api('issues/73/comments','POST',{body:report});
  if(error||!result.valid)process.exitCode=1;
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={validate,completedSeven,latestRun,rulesetStatus,format};
