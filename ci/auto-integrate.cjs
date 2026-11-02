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
 return files.every(f=>f.status!=='removed'&&
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
async function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 const cmd=validateEvent(event,process.env);
 const githubApi=(endpoint,method='GET',body)=>api(endpoint,method,body);
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
module.exports={validateEvent,safeFiles,verify};
