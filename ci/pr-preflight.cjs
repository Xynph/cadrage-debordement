'use strict';
const fs=require('node:fs'),{execFileSync}=require('node:child_process');
const REPO='Xynph/cadrage-debordement',OWNER=350229047,REPO_ID=1439603196;
const REQUIRED=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
const SHA=/^[0-9a-f]{40}$/;
function need(v,m){if(!v)throw Error(m);}
function parseEvent(e,env){
 need(env.GITHUB_EVENT_NAME==='issue_comment'&&env.GITHUB_REPOSITORY===REPO&&env.GITHUB_ACTOR==='Xynph'&&env.GITHUB_TRIGGERING_ACTOR==='Xynph','Événement non autorisé');
 need(e.action==='created'&&e.repository?.id===REPO_ID&&e.repository?.full_name===REPO&&e.issue?.number===73&&!e.issue.pull_request,'Issue invalide');
 need(e.sender?.id===OWNER&&e.comment?.user?.id===OWNER&&e.sender.login==='Xynph'&&e.comment.user.login==='Xynph','Auteur invalide');
 const m=String(e.comment.body||'').match(/^\/cd-preflight ([1-9][0-9]*) ([0-9a-f]{40})$/);
 need(m&&m[0]===e.comment.body&&Number.isSafeInteger(Number(m[1])),'Commande invalide');
 return {number:Number(m[1]),expected:m[2],commentId:e.comment.id};
}
function assess({pr,expected,main,runs,jobs,files,otherFiles,comments}){
 const errors=[];
 if(pr?.state!=='open'||pr?.base?.ref!=='main'||pr?.base?.sha!==main||pr?.head?.sha!==expected||pr?.head?.repo?.full_name!==REPO||!SHA.test(expected))errors.push('PR, HEAD ou base non conformes');
 if(pr?.mergeable!==true||pr?.mergeable_state!=='clean')errors.push('mergeable_state non clean');
 const matches=(runs||[]).filter(r=>r.event==='pull_request'&&r.name==='Tests JavaScript'&&r.head_sha===expected).sort((a,b)=>b.id-a.id);
 const run=matches[0];
 if(!run||run.status!=='completed'||run.conclusion!=='success')errors.push('CI non verte au HEAD exact');
 if(!run||!Array.isArray(jobs)||jobs.length!==7||!REQUIRED.every(n=>jobs.filter(j=>j.name===n&&j.status==='completed'&&j.conclusion==='success').length===1))errors.push('CI 7/7 non confirmée');
 const own=new Set(files||[]);
 if(!own.size)errors.push('Fichiers PR non vérifiables');
 const overlaps=(otherFiles||[]).filter(x=>own.has(x.path));
 if(overlaps.length)errors.push('Chevauchement avec une PR ouverte');
 const evidence=(comments||[]).filter(c=>c.user?.login==='Xynph'&&String(c.body||'').includes('RÉSERVATION')&&String(c.body||'').includes('#'+pr.number)&&[...own].every(p=>String(c.body||'').includes(p)));
 if(!evidence.length)errors.push('Réservation complète #73 non attestée');
 return {technicalPass:errors.length===0,errors,overlaps,runId:run?.id||null,reservationCommentId:evidence.at(-1)?.id||null,ruleSet:{id:26326518,bypassActors:'INCONNU',attested:false},authorizedToMerge:false};
}
function gh(path,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+path];
 if(body!==undefined)args.push('--input','-');
 const out=execFileSync('gh',args,{input:body===undefined?undefined:JSON.stringify(body),encoding:'utf8',timeout:30000,maxBuffer:10000000});
 return out.trim()?JSON.parse(out):null;
}
function pages(path,key,max=30){
 const result=[];
 for(let p=1;p<=max;p++){
  const response=gh(path+(path.includes('?')?'&':'?')+'per_page=100&page='+p);
  const rows=key?response?.[key]:response;
  need(Array.isArray(rows),'Pagination GitHub invalide');
  result.push(...rows);
  if(rows.length<100)return result;
 }
 throw Error('Pagination excessive');
}
function run(cmd,e){
 const fresh=gh('issues/comments/'+cmd.commentId);
 need(fresh?.body===e.comment.body&&fresh?.user?.id===OWNER&&fresh?.issue_url==='https://api.github.com/repos/'+REPO+'/issues/73','Commentaire modifié ou non authentifié');
 const main=gh('git/ref/heads/main')?.object?.sha;
 need(SHA.test(main),'main absent');
 const pr=gh('pulls/'+cmd.number),files=pages('pulls/'+cmd.number+'/files').map(x=>x.filename);
 const runs=pages('actions/runs?event=pull_request&head_sha='+cmd.expected,'workflow_runs',5);
 const latest=runs.filter(r=>r.name==='Tests JavaScript'&&r.head_sha===cmd.expected).sort((a,b)=>b.id-a.id)[0];
 const jobs=latest?pages('actions/runs/'+latest.id+'/jobs','jobs',10):[];
 const others=pages('pulls?state=open',null,10),otherFiles=[];
 for(const other of others)if(other.number!==cmd.number)
  for(const f of pages('pulls/'+other.number+'/files'))otherFiles.push({pr:other.number,path:f.filename});
 const comments=pages('issues/73/comments',null,30);
 const mainWorkflow=gh('actions/workflows/tests.yml');
 const mainRuns=pages('actions/workflows/tests.yml/runs?branch=main', 'workflow_runs', 3);
 const mainRun=mainRuns.filter(r=>r.workflow_id===mainWorkflow.id&&r.head_branch==='main'&&r.head_sha===main&&['push','workflow_dispatch'].includes(r.event)).sort((a,b)=>b.id-a.id)[0];
 const mainJobs=mainRun?pages('actions/runs/'+mainRun.id+'/jobs','jobs',10):[];
 const mainCI=require('./chat-release.cjs').fullCI(mainRun,mainJobs,main,mainWorkflow.id);
 // Décision existante réutilisée à titre consultatif ; DRAFT autorisé pour le diagnostic uniquement.
 const decision=require('./release-gate.cjs').decide({...pr,draft:false},runs,jobs);
 const result=assess({pr,expected:cmd.expected,main,runs,jobs,files,otherFiles,comments});
 if(!decision.ready)result.errors.push('Gate existant : '+decision.reason);
 if(!mainCI)result.errors.push('Main : CI complète 7/7 non validée');
 if(gh('git/ref/heads/main')?.object?.sha!==main||gh('pulls/'+cmd.number)?.head?.sha!==cmd.expected)result.errors.push('Main ou HEAD a changé durant le contrôle');
 result.technicalPass=result.errors.length===0;
 return {...result,pr:cmd.number,head:cmd.expected,main,mainCIRunId:mainRun?.id||null,draft:pr.draft,mergeableState:pr.mergeable_state};
}
function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8')),cmd=parseEvent(event,process.env);
 let result;
 try{result=run(cmd);}catch(err){result={technicalPass:false,errors:[String(err.message)],authorizedToMerge:false,ruleSet:{id:26326518,bypassActors:'INCONNU',attested:false}};}
 const status=result.technicalPass?'PRÉCONTRÔLE TECHNIQUE VERT — RULESET NON ATTESTÉ':'STOP PRÉCONTRÔLE';
 const message='### '+status+' — PR #'+cmd.number+'\n\nHEAD : '+cmd.expected+'\n\n    '+JSON.stringify(result)+'\n\nAucune attestation de bypass_actors=[], aucun READY, aucun /cd-check, aucun /cd-merge, aucune fusion. Gate officiel toujours requis.';
 fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,message+'\n');
 gh('issues/73/comments','POST',{body:message});
 if(!result.technicalPass)process.exitCode=1;
}
if(require.main===module)main();
module.exports={parseEvent,assess};
