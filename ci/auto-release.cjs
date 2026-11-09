'use strict';

// Dispatch explicite sur le code de main. La PR est inspectée via l'API GitHub.
const fs=require('node:fs');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const {execute,JOBS}=require('./chat-release.cjs');

const REPO='Xynph/cadrage-debordement', REPO_ID=1439603196, OWNER_ID=350229047;
const SHA=/^[a-f0-9]{40}$/;
const JS='Tests JavaScript', CHROMIUM='UI Chromium mutualise - CI V3';
const CHROMIUM_JOB='UI — Chromium mutualisé (7 parcours)';
const DOCS=new Set([
 'docs/ui01-integration-review.md',
 'docs/ui02-player-components.md',
 'docs/ui03-scout-center.md',
 'docs/ui04-academy.md'
]);
const CSS=new Set([
 'dist/style.css',
 'dist/main-menu-v3.css',
 'dist/ui01-integration.css',
 'dist/ui02-player-components.css',
 'dist/ui03-scout-components.css',
 'dist/ui04-academy-components.css'
]);

function need(value,message){
 if(!value)throw Error(message);
}
function owner(user){
 return user?.id===OWNER_ID&&user.login==='Xynph'&&user.type==='User';
}
function repository(repo){
 return repo?.id===REPO_ID&&repo.full_name===REPO;
}
function positive(id){
 return Number.isSafeInteger(id)&&id>0;
}

function validateDispatch(event,env){
 need(env.GITHUB_EVENT_NAME==='workflow_dispatch'&&env.GITHUB_REPOSITORY===REPO&&
   env.GITHUB_REF==='refs/heads/main'&&SHA.test(env.GITHUB_SHA)&&
   env.GITHUB_ACTOR==='Xynph'&&env.GITHUB_ACTOR_ID===String(OWNER_ID)&&
   env.GITHUB_TRIGGERING_ACTOR==='Xynph'&&env.GITHUB_RUN_ATTEMPT==='1'&&
   repository(event.repository)&&owner(event.sender),'Dispatch sur main ou acteur non autorisé');
 const {pr,sha,mode}=event.inputs||{};
 need(typeof pr==='string'&&String(Number(pr))===pr&&positive(Number(pr))&&
   typeof sha==='string'&&sha.length===40&&SHA.test(sha)&&['check','merge'].includes(mode),
   'Paramètres de sélection invalides (PR, SHA, mode)');
 need(mode!=='merge'||env.CD_ORDINARY_MERGE_ENABLED==='true','CD_ORDINARY_MERGE_ENABLED doit valoir true');
 return {pr:Number(pr),expected:sha,mode};
}

function validateProtection(rules){
 need(Array.isArray(rules)&&
   rules.some(r=>r.type==='pull_request'&&r.parameters?.allowed_merge_methods?.includes('squash'))&&
   rules.some(r=>r.type==='deletion')&&rules.some(r=>r.type==='non_fast_forward')&&
   rules.some(r=>r.type==='required_status_checks'&&r.parameters?.strict_required_status_checks_policy===true&&
     r.parameters.required_status_checks?.some(c=>c.context==='Validation CI'&&c.integration_id===15368)),
   'Protection main attendue absente (PR, squash, Validation CI stricte de GitHub Actions)');
}
function validateCandidate(pr,cmd,main){
 need(pr?.number===cmd.pr&&pr.state==='open'&&pr.draft===false&&owner(pr.user)&&
   pr.base?.ref==='main'&&pr.base.sha===main&&repository(pr.base.repo)&&
   pr.head?.sha===cmd.expected&&repository(pr.head.repo)&&
   pr.mergeable===true&&pr.mergeable_state==='clean','PR, HEAD, main ou état de fusion invalide');
}

function safeFile(file){
 if(file.previous_filename!==undefined||!SHA.test(file.sha||''))return false;
 if(file.status==='modified'&&(CSS.has(file.filename)||DOCS.has(file.filename)))return true;
 return ['added','modified'].includes(file.status)&&
   /^docs\/ui-presentation-[a-z0-9-]+\.md$/.test(file.filename);
}
function verifyBlobs(api,head,files){
 function tree(sha){
  const result=api('git/trees/'+sha);
  need(result?.truncated===false&&Array.isArray(result.tree),'Arbre Git incomplet');
  return result.tree;
 }
 const root=tree(head),directories=new Map();
 for(const file of files){
  const [directory,name]=file.filename.split('/');
  if(!directories.has(directory)){
   const entry=root.find(e=>e.path===directory);
   need(entry?.type==='tree'&&entry.mode==='040000'&&SHA.test(entry.sha),'Arbre Git inattendu');
   directories.set(directory,tree(entry.sha));
  }
  const entry=directories.get(directory).find(e=>e.path===name);
  need(entry?.type==='blob'&&entry.mode==='100644'&&entry.sha===file.sha,
   'Le fichier doit être un blob Git ordinaire au HEAD exact');
 }
}

function paginate(api,endpoint,limit){
 const all=[];
 for(let page=1;page<=limit;page++){
  const rows=api(endpoint+'per_page=100&page='+page);
  need(Array.isArray(rows)&&rows.length<=100,'Pagination GitHub invalide');
  all.push(...rows);
  if(rows.length<100)return all;
 }
 throw Error('Pagination GitHub incomplète pour '+endpoint);
}
function readyPRs(api){
 const prs=paginate(api,'pulls?state=open&base=main&sort=created&direction=asc&',5);
 need(prs.every(p=>positive(p.number)&&p.state==='open'&&typeof p.draft==='boolean')&&
   new Set(prs.map(p=>p.number)).size===prs.length,'Liste de PR concurrentes ambiguë');
 const ready=prs.filter(p=>!p.draft);
 need(ready.every(p=>p.base?.ref==='main'&&SHA.test(p.base.sha)&&SHA.test(p.head?.sha)),
   'Têtes de PR concurrentes incomplètes');
 return ready.map(p=>[p.number,p.head.sha,p.base.sha]);
}
function checkCollisions(api,cmd,main,files){
 const open=readyPRs(api);
 need(open.some(([n,head,base])=>n===cmd.pr&&head===cmd.expected&&base===main),
   'La PR sélectionnée a changé pendant le contrôle');
 const own=files.map(f=>f.filename.toLowerCase());
 for(const [number] of open){
  if(number===cmd.pr)continue;
  // L'API GitHub limite le diff à 3 000 entrées. Une dernière page pleine
  // peut masquer des chemins. Inspecter également l'origine des renommages.
  const changed=paginate(api,'pulls/'+number+'/files?',30);
  for(const entry of changed){
   const paths=[entry.filename];
   if(entry.status==='renamed'||entry.previous_filename!==undefined)paths.push(entry.previous_filename);
   need(typeof entry.status==='string'&&paths.every(p=>typeof p==='string'&&p.length>0),
     'Diff concurrent illisible pour la PR #'+number);
   const collision=paths.some(p=>{
    const candidate=p.toLowerCase();
    return own.some(f=>f===candidate||f.startsWith(candidate+'/')||candidate.startsWith(f+'/'));
   });
   need(!collision,'Chevauchement de fichiers avec la PR #'+number);
  }
 }
 need(JSON.stringify(readyPRs(api))===JSON.stringify(open),'Les PR concurrentes ont changé pendant le contrôle');
}

function terminalJobs(api,run){
 const page=api('actions/runs/'+run.id+'/attempts/'+run.run_attempt+'/jobs?per_page=100');
 need(Array.isArray(page?.jobs)&&page.jobs.length===page.total_count,'Liste de jobs incomplète');
 return page.jobs;
}
function greenJobs(jobs,expected){
 return jobs.length===expected.length&&expected.every(([name,conclusion])=>
   jobs.filter(j=>j.name===name&&j.status==='completed'&&j.conclusion===conclusion).length===1);
}
function verifyCI(api,pr,files){
 const css=files.some(f=>CSS.has(f.filename));
 const tests=api('actions/workflows/tests.yml');
 need(tests?.state==='active'&&tests.name===JS&&positive(tests.id),'Tests JavaScript indisponible');
 const chromium=css?api('actions/workflows/ui-browser-consolidated.yml'):null;
 need(!css||(chromium?.state==='active'&&chromium.name===CHROMIUM&&positive(chromium.id)),
   'Chromium requis et indisponible');
 const page=api('actions/runs?event=pull_request&head_sha='+pr.head.sha+'&per_page=100');
 need(Array.isArray(page?.workflow_runs)&&page.workflow_runs.length===page.total_count,'Liste de CI PR incomplète');
 const latest=new Map();
 for(const run of page.workflow_runs){
  if(run.event!=='pull_request'||run.head_sha!==pr.head.sha||run.head_branch!==pr.head.ref)continue;
  need(positive(run.id)&&positive(run.workflow_id)&&positive(run.run_attempt)&&
    run.pull_requests?.some(p=>p.number===pr.number&&p.head?.sha===pr.head.sha&&
      p.head.repo?.id===REPO_ID&&p.base?.ref==='main'&&p.base.sha===pr.base.sha&&p.base.repo?.id===REPO_ID),
    'CI PR sans association à la tête, à la PR et à sa base');
  if((latest.get(run.workflow_id)?.id||0)<run.id)latest.set(run.workflow_id,run);
 }
 const js=latest.get(tests.id);
 need(js?.name===JS,'Tests JavaScript absent sur la PR et le HEAD exacts');
 if(css)need(latest.get(chromium.id)?.name===CHROMIUM,'Chromium absent sur la PR et le HEAD exacts');
 for(const run of latest.values()){
  need(run.status==='completed'&&run.conclusion==='success','CI PR en attente ou non réussie (run '+run.id+')');
 }
 const green=JOBS.map(name=>[name,'success']);
 const docs=[['classification','success'],['Validation CI','success'],['Suites ${{ matrix.shard }}/5','skipped']];
 const jobs=terminalJobs(api,js);
 need(greenJobs(jobs,green)||(!css&&greenJobs(jobs,docs)),'Jobs JavaScript inattendus ou incomplets');
 if(css)need(greenJobs(terminalJobs(api,latest.get(chromium.id)),[[CHROMIUM_JOB,'success']]),
   'Job Chromium manquant ou non réussi');
 return js;
}

function api(endpoint,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+endpoint];
 if(body)args.push('--input','-');
 const out=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,
   timeout:30000,maxBuffer:16*1024*1024});
 return out.trim()?JSON.parse(out):null;
}
function runGate(pr,expected,merge,main,run){
 try{
  return execFileSync(process.execPath,[path.join(__dirname,'release-gate.cjs'),String(pr),...(merge?['--merge']:[])],
   {encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,env:{
    ...process.env,CD_REPO:REPO,CD_EXPECTED_HEAD_SHA:expected,CD_EXPECTED_BASE_SHA:main,
    CD_EXPECTED_CI_RUN:String(run.id),CD_EXPECTED_CI_ATTEMPT:String(run.run_attempt)
   }});
 }catch(error){
  throw Error('Gate officiel refusé : '+String(error.stdout||'').slice(0,2000)+' '+String(error.stderr||'').slice(0,1000));
 }
}

async function runAuto(event,env,services={}){
 const cmd=validateDispatch(event,env),req=services.api||api,main=env.GITHUB_SHA;
 need(req('git/ref/heads/main').object.sha===main,'main a changé depuis la sélection');
 validateProtection(req('rules/branches/main'));
 const pr=req('pulls/'+cmd.pr);
 validateCandidate(pr,cmd,main);
 const files=req('pulls/'+cmd.pr+'/files?per_page=100');
 need(Array.isArray(files)&&files.length===pr.changed_files&&files.length>0&&files.length<=12&&
   new Set(files.map(f=>f.filename)).size===files.length,'Diff incomplet, vide ou trop grand');
 need(files.every(safeFile),'Fichier hors périmètre de la fusion ordinaire');
 verifyBlobs(req,cmd.expected,files);
 checkCollisions(req,cmd,main,files);
 validateCandidate(req('pulls/'+cmd.pr),cmd,main);
 const js=verifyCI(req,pr,files);
 return (services.execute||execute)(cmd,event,{
  api:req,snapshot:main,autoAuthorized:true,
  sleep:ms=>new Promise(resolve=>setTimeout(resolve,ms)),
  execGate:(number,expected,merge)=>runGate(number,expected,merge,main,js),
  watch:id=>execFileSync('gh',['run','watch',String(id),'--repo',REPO,'--interval','30','--exit-status'],
    {stdio:'inherit',timeout:32*60*1000})
 });
}

async function main(){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 const summary=message=>fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,message+'\n');
 try{
  const result=await runAuto(event,process.env);
  const subject='PR #'+result.pr+' · HEAD `'+result.expected+'`';
  if(result.mode==='check'){
   summary(subject+' · Contrôles réussis. Contrôle en lecture seule.');
  }else{
   summary(subject+' · Fusion `'+result.mergedSha+'` · [CI post-fusion 7/7](https://github.com/'+REPO+'/actions/runs/'+result.postRun+')');
  }
  console.log(JSON.stringify(result));
 }catch(error){
  summary('### Fusion ordinaire · STOP\n\n'+error.message+
    '\n\nSi le squash a déjà eu lieu, vérifier le commit main et son verdict CI avant toute nouvelle demande.');
  throw error;
 }
}
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={runAuto};
