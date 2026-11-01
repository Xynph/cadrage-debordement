'use strict';
// Seul le code de main est exécuté avec le jeton ; jamais celui de la PR.
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const REPO='Xynph/cadrage-debordement',OWNER_ID=350229047,REPO_ID=1439603196;
const JOBS=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
function need(value,message){if(!value)throw Error(message);}
function owner(user){return user?.id===OWNER_ID&&user.login==='Xynph'&&user.type==='User';}
function validateEvent(e,env){
 need(env.GITHUB_EVENT_NAME==='issue_comment'&&env.GITHUB_REPOSITORY===REPO&&env.GITHUB_ACTOR==='Xynph'&&env.GITHUB_TRIGGERING_ACTOR==='Xynph','Événement ou acteur non autorisé');
 need(e.action==='created'&&e.repository?.full_name===REPO&&e.repository.id===REPO_ID&&e.issue?.number===73&&!e.issue.pull_request,'Dépôt/issue/événement non autorisé');
 need(owner(e.comment?.user)&&e.sender?.id===OWNER_ID&&e.sender.login==='Xynph'&&Number.isSafeInteger(e.comment.id),'Auteur non autorisé');
 const body=e.comment.body,m=typeof body==='string'&&body.match(/^\/cd-(merge|check) ([1-9][0-9]*) ([0-9a-f]{40})$/);
 need(m&&m[0]===body&&Number.isSafeInteger(Number(m[2])),'Commande stricte attendue : /cd-merge PR SHA40 ou /cd-check PR SHA40');
 return {pr:Number(m[2]),expected:m[3],mode:m[1],commentId:e.comment.id};
}
function fullCI(run,jobs,sha,workflowId){
 return !!run&&run.workflow_id===workflowId&&run.head_branch==='main'&&run.head_sha===sha&&['push','workflow_dispatch'].includes(run.event)&&run.name==='Tests JavaScript'&&run.status==='completed'&&run.conclusion==='success'&&jobs.length===JOBS.length&&JOBS.every(name=>jobs.filter(j=>j.name===name&&j.status==='completed'&&j.conclusion==='success').length===1);
}
function latestCI(runs,sha,id){return runs.filter(r=>r.workflow_id===id&&r.head_sha===sha&&r.head_branch==='main'&&['push','workflow_dispatch'].includes(r.event)).sort((a,b)=>b.id-a.id)[0];}
async function execute(cmd,event,d){
 const api=d.api,head=()=>api('git/ref/heads/main').object.sha;
 const fresh=api('issues/comments/'+cmd.commentId);
 need(owner(fresh.user)&&fresh.body===event.comment.body&&fresh.issue_url==='https://api.github.com/repos/'+REPO+'/issues/73','Commentaire modifié, déplacé ou auteur invalide');
 const base=head();need(base===d.snapshot,'main a changé depuis cet événement ; soumettre une nouvelle commande');
 const workflow=api('actions/workflows/tests.yml');need(workflow.state==='active','CI principale inactive');
 const listRuns=()=>api('actions/workflows/tests.yml/runs?branch=main&per_page=100').workflow_runs;
 const listJobs=id=>{const all=[];for(let page=1;page<=10;page++){const batch=api('actions/runs/'+id+'/jobs?per_page=100&page='+page).jobs;all.push(...batch);if(batch.length<100)return all;}throw Error('Pagination CI excessive');};
 const before=latestCI(listRuns(),base,workflow.id);
 need(fullCI(before,before?listJobs(before.id):[],base,workflow.id),'main ne possède pas une CI complète verte ; arrêter les intégrations');
 need(api('pulls/'+cmd.pr).head?.sha===cmd.expected,'SHA attendu différent de HEAD');
 need(head()===base,'main a changé avant le gate');
 // Le CLI revérifie le SHA attendu dans sa propre lecture, puis GitHub le
 // compare atomiquement au moment du squash. Les critères decide() sont intacts.
 const output=d.execGate(cmd.pr,cmd.expected,cmd.mode==='merge');
 if(cmd.mode==='check')return {mode:'check',pr:cmd.pr,expected:cmd.expected,ready:true};
 const match=output.match(/^Fusion ([0-9a-f]{40}) : verifier une seule fois le run push main sur ce SHA\.$/m);
 need(match,'Reçu de fusion officiel absent ; consulter le run, aucune livraison déclarée');
 const mergedSha=match[1];need(head()===mergedSha,'main ne correspond pas au reçu de fusion');
 const known=new Set(listRuns().map(r=>r.id));
 const dispatched=api('actions/workflows/tests.yml/dispatches','POST',{ref:'main'});
 let post=Number.isSafeInteger(dispatched?.workflow_run_id)?api('actions/runs/'+dispatched.workflow_run_id):undefined;
 for(let attempt=0;!post&&attempt<20;attempt++){
  const candidates=listRuns().filter(r=>!known.has(r.id)&&r.workflow_id===workflow.id&&r.head_sha===mergedSha&&r.head_branch==='main'&&r.event==='workflow_dispatch');
  need(candidates.length<=1,'Plusieurs dispatchs concurrents : identité de la CI ambiguë');
  if(candidates.length===1){post=candidates[0];break;}
  await d.sleep(6000);
 }
 need(post,'CI post-fusion du SHA exact introuvable');
 d.watch(post.id);
 const completed=api('actions/runs/'+post.id);
 need(fullCI(completed,listJobs(post.id),mergedSha,workflow.id),'CI post-fusion incomplète ou non verte');
 need(head()===mergedSha,'main a changé pendant la validation ; vérifier l’autre intégration');
 return {mode:'merge',pr:cmd.pr,expected:cmd.expected,mergedSha,postRun:post.id,passed:true};
}
function api(endpoint,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+endpoint];if(body)args.push('--input','-');
 const raw=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000,maxBuffer:8*1024*1024});
 return raw.trim()?JSON.parse(raw):null;
}
async function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8')),cmd=validateEvent(event,process.env);
 let result,error;
 try{
  result=await execute(cmd,event,{api,snapshot:process.env.GITHUB_SHA,sleep:ms=>new Promise(resolve=>setTimeout(resolve,ms)),
   execGate:(pr,expected,merge)=>execFileSync(process.execPath,[path.join(__dirname,'release-gate.cjs'),String(pr),...(merge?['--merge']:[])],{encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,env:{...process.env,CD_REPO:REPO,CD_EXPECTED_HEAD_SHA:expected}}),
   watch:id=>execFileSync('gh',['run','watch',String(id),'--repo',REPO,'--interval','30','--exit-status'],{stdio:'inherit',timeout:32*60*1000})});
 }catch(e){error=e;}
 const runUrl='https://github.com/'+REPO+'/actions/runs/'+process.env.GITHUB_RUN_ID;
 const message=error?'ÉCHEC — aucune livraison validée. Une fusion peut avoir eu lieu avant cet échec : consulter le run et main avant toute nouvelle commande.':result.mode==='check'?'CONTRÔLE VERT — aucune fusion effectuée.':'SUCCÈS — fusion '+result.mergedSha+' ; CI post-fusion 7/7 : https://github.com/'+REPO+'/actions/runs/'+result.postRun;
 const summary='Chat release gate — PR #'+cmd.pr+' — HEAD `'+cmd.expected+'`\n\n'+message+'\n\nRun : '+runUrl;
 fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,summary+'\n');api('issues/73/comments','POST',{body:summary});
 if(error)throw error;console.log(JSON.stringify(result));
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={validateEvent,fullCI,latestCI,execute};
