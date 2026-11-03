'use strict';
// Merge déclenché par étiquette du propriétaire, avec le même gate que /cd-merge.
// Le code exécuté provient exclusivement de main ; aucun script de PR n'est lancé ici.
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const {execute}=require('./chat-release.cjs');
const REPO='Xynph/cadrage-debordement',REPO_ID=1439603196,OWNER_ID=350229047;
const LABEL='cd-integrate';
function need(ok,why){if(!ok)throw Error(why);}
function validateEvent(e,env){
 need(env.GITHUB_EVENT_NAME==='pull_request_target'&&env.GITHUB_REPOSITORY===REPO&&
   env.GITHUB_ACTOR==='Xynph'&&env.GITHUB_TRIGGERING_ACTOR==='Xynph',
   'Seul le propriétaire peut déclencher cette intégration');
 need(e.action==='labeled'&&e.repository?.full_name===REPO&&e.repository?.id===REPO_ID&&
   e.label?.name===LABEL&&e.sender?.id===OWNER_ID&&e.sender?.login==='Xynph'&&
   e.sender?.type==='User','Étiquette, dépôt ou propriétaire invalide');
 const pr=e.pull_request;
 need(Number.isSafeInteger(pr?.number)&&pr.number>0&&pr.base?.ref==='main'&&
   pr.base?.repo?.full_name===REPO&&pr.head?.repo?.full_name===REPO&&
   /^[0-9a-f]{40}$/.test(pr.head?.sha||'')&&
   /^[0-9a-f]{40}$/.test(env.GITHUB_SHA||''),
   'PR ou SHAs invalides');
 return {pr:pr.number,expected:pr.head.sha,base:env.GITHUB_SHA,mode:'merge'};
}
function safeFiles(files){
 need(Array.isArray(files)&&files.length>0&&files.length<100,
   'Diff absent ou pagination indécidable');
 // La voie rapide exclut les changements privilégiés, moteur et sauvegardes.
 return files.every(f=>['added','modified'].includes(f.status)&&
   (/^tests\/[a-zA-Z0-9._-]+\.cjs$/.test(f.filename)||
    /^dist\/[a-zA-Z0-9._-]+\.js$/.test(f.filename))&&
   !/^(dist\/(?:rugby|saves|index|game|economy|world-career)\.js|tests\/(?:chat-release|release-gate)\.cjs)$/.test(f.filename));
}
function verify(cmd,api){
 const pr=api('pulls/'+cmd.pr);
 need(pr.number===cmd.pr&&pr.state==='open'&&!pr.draft&&pr.head?.sha===cmd.expected&&
   pr.base?.ref==='main'&&pr.base?.sha===cmd.base&&
   pr.head?.repo?.full_name===REPO&&pr.base?.repo?.full_name===REPO&&
   pr.labels?.some(l=>l.name===LABEL),
   'La PR, sa base ou son étiquette a changé');
 const files=api('pulls/'+cmd.pr+'/files?per_page=100');
 need(safeFiles(files),'Changements sensibles ou diff trop grand : contrôle manuel requis');
 return true;
}
function api(endpoint,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+endpoint];
 if(body)args.push('--input','-');
 const raw=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000,maxBuffer:8*1024*1024});
 return raw.trim()?JSON.parse(raw):null;
}
function validateDispatch(e,env,transport){
 need(env.GITHUB_EVENT_NAME==='workflow_dispatch'&&env.GITHUB_REPOSITORY===REPO&&
   env.GITHUB_REF==='refs/heads/main'&&/^[0-9a-f]{40}$/.test(env.GITHUB_SHA||''),
   'Dispatch uniquement sur main');
 const i=e.inputs||{};
 need(/^[1-9][0-9]*$/.test(i.pr||'')&&/^[1-9][0-9]*$/.test(i.source_run||'')&&
   /^[0-9a-f]{40}$/.test(i.sha||'')&&Number.isSafeInteger(Number(i.pr))&&
   Number.isSafeInteger(Number(i.source_run)),'Paramètres de sélection invalides');
 // pull_request_target runs on the trusted base commit, NOT on the PR head SHA.
 // Preserve both invariants: source run on this exact main and live PR HEAD
 // matching i.sha (validated separately by verify before privileged execution).
 const source=transport('actions/runs/'+i.source_run);
 need(source?.event==='pull_request_target'&&
   source.path==='.github/workflows/auto-integrate-request.yml'&&
   source.actor?.id===OWNER_ID&&source.actor?.login==='Xynph'&&
   source.actor?.type==='User'&&source.status==='completed'&&
   source.conclusion==='success'&&source.head_sha===env.GITHUB_SHA&&
   source.pull_requests?.some(p=>p.number===Number(i.pr)),
   'Provenance propriétaire et sélection terminée non démontrées');
 return {pr:Number(i.pr),expected:i.sha,base:env.GITHUB_SHA,mode:'merge'};
}
async function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 const githubApi=(endpoint,method='GET',body)=>api(endpoint,method,body);
 const cmd=validateDispatch(event,process.env,githubApi);
 let receipt;
 try{
   verify(cmd,githubApi);
   receipt=await execute(cmd,event,{
     api:githubApi,snapshot:cmd.base,autoAuthorized:true,
     sleep:ms=>new Promise(resolve=>setTimeout(resolve,ms)),
     execGate:(number,sha,merge)=>execFileSync(process.execPath,
       [path.join(__dirname,'release-gate.cjs'),String(number),...(merge?['--merge']:[])],
       {encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,
        env:{...process.env,CD_REPO:REPO,CD_EXPECTED_HEAD_SHA:sha}}),
     watch:id=>execFileSync('gh',['run','watch',String(id),'--repo',REPO,'--interval','30','--exit-status'],
       {stdio:'inherit',timeout:32*60*1000})
   });
   const message='Intégration automatique contrôlée — PR #'+cmd.pr+
     ' — HEAD `'+cmd.expected+'` → main `'+receipt.mergedSha+
     '` ; CI post-fusion 7/7 : https://github.com/'+REPO+'/actions/runs/'+receipt.postRun;
   fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,message+'\n');
   api('issues/73/comments','POST',{body:message});
   console.log(JSON.stringify(receipt));
 }catch(error){
   const message='Intégration rapide STOP — PR #'+cmd.pr+' — HEAD `'+cmd.expected+
     '` : aucun succès revendiqué. Une fusion pourrait précéder un échec de CI ; inspecter main et le run. '+error.message;
   if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,message+'\n');
   try{api('issues/73/comments','POST',{body:message});}catch(_){}
   throw error;
 }
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={validateEvent,validateDispatch,safeFiles,verify};
