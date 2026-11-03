'use strict';
// Précontrôle CI en lecture seule. Exécute uniquement le gate officiel sur le code de main.
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const REPO='Xynph/cadrage-debordement';
const EXPECTED=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
function candidates(event){
  const r=event?.workflow_run;
  if(event?.action!=='completed'||r?.name!=='Tests JavaScript'||r?.event!=='pull_request'||
     r?.status!=='completed'||r?.conclusion!=='success'||!/^[0-9a-f]{40}$/.test(r?.head_sha||'')||
     !Number.isSafeInteger(r.id)||!Array.isArray(r.pull_requests))return [];
  return [...new Set(r.pull_requests.filter(p=>Number.isSafeInteger(p?.number)&&p.number>0&&
    p.base?.ref==='main'&&p.head?.sha===r.head_sha).map(p=>p.number))].slice(0,10);
}
function seven(jobs){
  return Array.isArray(jobs)&&jobs.length===EXPECTED.length&&EXPECTED.every(name=>
    jobs.filter(j=>j.name===name&&j.status==='completed'&&j.conclusion==='success').length===1);
}
function eligible(pr,sha){
  return pr?.state==='open'&&pr.base?.ref==='main'&&pr.head?.sha===sha&&
    pr.head?.repo?.full_name===REPO&&pr.draft===false&&pr.mergeable===true&&
    pr.mergeable_state==='clean';
}
function api(endpoint){
  return JSON.parse(execFileSync('gh',['api','--method','GET','repos/'+REPO+'/'+endpoint],{
    encoding:'utf8',timeout:25000,maxBuffer:8*1024*1024
  }));
}
function summary(event,get=api,gate=(number,sha)=>execFileSync(process.execPath,
    [require('node:path').join(__dirname,'release-gate.cjs'),String(number)],{
      encoding:'utf8',timeout:65000,env:{...process.env,CD_REPO:REPO,CD_EXPECTED_HEAD_SHA:sha}
    })){
  const numbers=candidates(event),run=event.workflow_run;
  if(!numbers.length)return 'Aucune PR éligible issue de cette CI : aucune action.';
  const jobs=get('actions/runs/'+run.id+'/jobs?per_page=100').jobs;
  if(!seven(jobs))return 'CI 7/7 non confirmée : aucun précontrôle autorisé.';
  const lines=['## Précontrôle automatique en lecture seule',''];
  for(const n of numbers){
    const pr=get('pulls/'+n);
    if(!eligible(pr,run.head_sha)){
      lines.push('- PR #'+n+' : non READY, SHA modifié ou fusion non propre ; gate non appelé.');
      continue;
    }
    try{
      gate(n,run.head_sha);
      lines.push('- PR #'+n+' : gate officiel vert sur HEAD exact. Fusion **non effectuée**.');
    }catch(e){
      lines.push('- PR #'+n+' : gate officiel bloquant (CI main, protections ou état). Fusion **non effectuée**.');
    }
  }
  lines.push('','Aucun commentaire, rerun, fusion ou changement de branche. Le propriétaire utilise toujours /cd-merge via le workflow officiel.');
  return lines.join('\n');
}
function main(){
  if(process.env.GITHUB_EVENT_NAME!=='workflow_run'||process.env.GITHUB_REPOSITORY!==REPO)
    throw Error('Événement/dépôt inattendu');
  const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
  const output=summary(event);
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,output+'\n');
  console.log(output);
}
if(require.main===module)try{main();}catch(e){console.error('STOP précontrôle : '+e.message);process.exitCode=1;}
module.exports={candidates,seven,eligible,summary};
