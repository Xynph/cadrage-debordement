'use strict';
// Diagnostic rapide strictement en lecture seule. Le gate officiel reste indispensable.
const {execFileSync}=require('node:child_process');
const REPO='Xynph/cadrage-debordement';
const SHA=/^[0-9a-f]{40}$/;
const CI_JOBS=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
function need(ok,msg){if(!ok)throw Error(msg);}
function latest(runs,sha){
 const m=new Map();
 for(const r of runs){
  if(r.event!=='pull_request'||r.head_sha!==sha)continue;
  need(Number.isSafeInteger(r.id)&&Number.isSafeInteger(r.workflow_id),'Identité de run absente');
  const ts=x=>{const t=Date.parse(x.updated_at||x.created_at);need(Number.isFinite(t),'Date invalide');return t;};
  const p=m.get(r.workflow_id);
  if(!p||ts(r)>ts(p)||(ts(r)===ts(p)&&r.id>p.id))m.set(r.workflow_id,r);
 }
 return [...m.values()].sort((a,b)=>a.workflow_id-b.workflow_id);
}
function seven(jobs){
 return Array.isArray(jobs)&&jobs.length===7&&CI_JOBS.every(n=>jobs.filter(j=>j.name===n&&j.status==='completed'&&j.conclusion==='success').length===1);
}
function evaluate({pr,main,collection,jobs=[],reads=0}){
 need(pr&&SHA.test(pr.head?.sha||'')&&SHA.test(main||''),'Snapshot invalide');
 need(collection&&Array.isArray(collection.workflow_runs)&&Number.isSafeInteger(collection.total_count),'Runs incomplets');
 const blockers=[],pending=[];
 const stop=(x,m)=>{if(x)blockers.push(m);},wait=(x,m)=>{if(x)pending.push(m);};
 stop(pr.state!=='open'||pr.draft,'PR fermée ou brouillon');
 stop(pr.base?.ref!=='main'||pr.base?.repo?.full_name!==REPO||pr.head?.repo?.full_name!==REPO,'Dépôt ou base invalide');
 stop(pr.base?.sha!==main,'La branche principale a avancé');
 stop(pr.mergeable===false||['dirty','blocked','behind','unstable'].includes(pr.mergeable_state),'PR non fusionnable');
 wait(pr.mergeable!==true||pr.mergeable_state!=='clean','Fusionabilité incertaine');
 stop(collection.total_count>collection.workflow_runs.length,'Pagination tronquée');
 const runs=latest(collection.workflow_runs,pr.head.sha);
 const candidates=runs.filter(r=>r.name==='Tests JavaScript'&&r.path==='.github/workflows/tests.yml');
 stop(candidates.length!==1,'Tests JavaScript absent ou ambigu');
 const ci=candidates[0];
 for(const r of runs){
  wait(r.status!=='completed','Workflow en cours : '+r.id);
  stop(r.status==='completed'&&r.conclusion!=='success','Workflow non vert : '+r.id);
 }
 if(ci?.status==='completed')stop(!seven(jobs),'Les sept jobs officiels ne sont pas tous verts');
 else if(ci)wait(true,'Validation CI en attente');
 return {status:blockers.length?'STOP':pending.length?'EN_ATTENTE':'CONTROLE_POSSIBLE',
  pr:pr.number,head:pr.head.sha,main,reads,ciRun:ci?.id||null,
  workflows:runs.map(r=>({id:r.id,name:r.name,status:r.status,conclusion:r.conclusion})),
  blockers,pending,
  disclaimer:'Bilan consultatif et non atomique. Appliquer les exigences du gate officiel en production.'};
}
function inspect(num,api){
 need(Number.isSafeInteger(num)&&num>0,'Numéro de PR positif exigé');
 let reads=0;const get=p=>{reads++;return api(p);};
 const main=get('git/ref/heads/main').object?.sha;
 const pr=get('pulls/'+num);
 need(pr?.number===num&&SHA.test(pr.head?.sha||''),'PR ou SHA incohérent');
 const col=get('actions/runs?event=pull_request&head_sha='+pr.head.sha+'&per_page=100');
 need(Array.isArray(col?.workflow_runs),'Runs absents');
 const ci=latest(col.workflow_runs,pr.head.sha).find(r=>r.name==='Tests JavaScript'&&r.path==='.github/workflows/tests.yml');
 const jobs=ci?get('actions/runs/'+ci.id+'/jobs?per_page=100').jobs:[];
 need(reads<=4,'Budget de quatre lectures dépassé');
 return evaluate({pr,main,collection:col,jobs,reads});
}
function render(s,handoff=false){
 const safe=x=>String(x??'').replace(/[\r\n<>|]/g,' ');
 const lines=[(handoff?'PASSATION CANDIDATE':'BILAN EXPRESS')+' — PR #'+s.pr,
  s.status+' ; '+s.reads+' lectures API ; aucune fusion.',
  'HEAD '+s.head+' ; main '+s.main,
  'CI '+(s.ciRun?'https://github.com/'+REPO+'/actions/runs/'+s.ciRun:'absente'),
  'Runs : '+(s.workflows.map(r=>safe(r.name)+' #'+r.id+' '+safe(r.status)+'/'+safe(r.conclusion)).join('; ')||'aucun'),
  s.blockers.length?'Blocages : '+s.blockers.join('; '):'',
  s.pending.length?'En attente : '+s.pending.join('; '):'',
  s.disclaimer,
  'Les consignes d’AGENTS.md et les descriptions de PR font référence.'];
 return lines.filter(Boolean).join('\n')+'\n';
}
function ghRead(endpoint){
 need(/^(?:git\/ref\/heads\/main|pulls\/[1-9][0-9]*|actions\/runs\?event=pull_request&head_sha=[0-9a-f]{40}&per_page=100|actions\/runs\/[1-9][0-9]*\/jobs\?per_page=100)$/.test(endpoint),'Endpoint non autorisé');
 return JSON.parse(execFileSync('gh',['api','--method','GET','repos/'+REPO+'/'+endpoint],
  {encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:25000,maxBuffer:8*1024*1024}));
}
function main(argv=process.argv.slice(2)){
 need(argv.length>0&&argv.length<=2&&/^[1-9][0-9]*$/.test(argv[0])&&(!argv[1]||['--handoff','--json'].includes(argv[1])),
  'Usage : node ci/development-snapshot.cjs NUMERO_PR [--handoff|--json]');
 const s=inspect(Number(argv[0]),ghRead);
 console.log(argv[1]==='--json'?JSON.stringify(s,null,2):render(s,argv[1]==='--handoff'));
 if(s.status!=='CONTROLE_POSSIBLE')process.exitCode=1;
}
if(require.main===module){try{main();}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={CI_JOBS,latest,seven,evaluate,inspect,render,ghRead};
