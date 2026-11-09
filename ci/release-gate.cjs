'use strict';
// Bilan unique et fusion volontaire : aucune boucle de polling.
// Usage : node ci/release-gate.cjs <numero-pr> [--merge]
// Prerequis : gh auth login, acces au depot et droits de fusion.
const {execFileSync}=require('node:child_process');
const repo=process.env.CD_REPO || 'Xynph/cadrage-debordement';
const SHA=/^[0-9a-f]{40}$/;

function latestPRRun(runs,sha){
  return (runs||[]).filter(run=>run.event==='pull_request' &&
    run.head_sha===sha && run.name==='Tests JavaScript').sort((a,b)=>b.id-a.id)[0];
}
function decide(pr,runs,jobs) {
  if (!pr || pr.state !== 'open' || pr.base?.ref !== 'main' || !pr.head?.sha ||
      pr.head.repo?.full_name !== repo || pr.draft ||
      pr.mergeable !== true || pr.mergeable_state !== 'clean') {
    return {ready:false,reason:'PR non fusionnable, base invalide ou etat incertain'};
  }
  const sha=pr.head.sha;
  const run=latestPRRun(runs,sha);
  if (!run || run.status!=='completed' || run.conclusion!=='success') {
    return {ready:false,reason:'CI PR complete non reussie sur le dernier SHA',sha,runId:run?.id};
  }
  const gate=(jobs||[]).find(job=>job.name==='Validation CI');
  if(!gate || gate.conclusion!=='success' || gate.status!=='completed') {
    return {ready:false,reason:'Controle Validation CI absent ou non vert',sha,runId:run.id};
  }
  return {ready:true,reason:'CI complete et controle final verts',sha,runId:run.id};
}
function api(url,method='GET',args=[]) {
  return JSON.parse(execFileSync('gh',['api','--method',method,url,...args],{
    encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:20000
  }));
}
function main(argv=process.argv.slice(2),request=api,env=process.env) {
  if (argv.length<1 || argv.length>2 || !/^\d+$/.test(argv[0]) ||
      (argv[1] && argv[1]!=='--merge')) {
    console.error('Usage : node ci/release-gate.cjs <PR> [--merge]');
    process.exitCode=2;return;
  }
  const prefix='repos/'+repo+'/',number=Number(argv[0]);
  const pr=request(prefix+'pulls/'+number);
  const expected=env.CD_EXPECTED_HEAD_SHA;
  const expectedBase=env.CD_EXPECTED_BASE_SHA;
  const expectedRun=env.CD_EXPECTED_CI_RUN;
  const expectedAttempt=env.CD_EXPECTED_CI_ATTEMPT;
  if(expected && (!SHA.test(expected) || pr.head?.sha!==expected)) {
    throw Error('SHA attendu different de la tete de PR : aucune fusion');
  }
  if(expectedBase && (!SHA.test(expectedBase)||pr.base?.ref!=='main'||pr.base.sha!==expectedBase)) {
    throw Error('Base main attendue differente de la PR : aucune fusion');
  }
  if (pr.state!=='open' || !SHA.test(pr.head?.sha||'')) {
    console.log('PR fermee ou sans SHA : aucune fusion');process.exitCode=1;return;
  }
  const all=request(prefix+'actions/workflows/tests.yml/runs?event=pull_request&head_sha='+pr.head.sha+'&per_page=100');
  const runs=all.workflow_runs||[];
  const selected=latestPRRun(runs,pr.head.sha);
  if(expectedRun!==undefined||expectedAttempt!==undefined){
    if(!selected||runs.length!==all.total_count||String(selected.id)!==expectedRun||
       String(selected.run_attempt)!==expectedAttempt){
      throw Error('La CI PR ou sa tentative a change : aucune fusion');
    }
  }
  const attempt=expectedAttempt!==undefined?'/attempts/'+selected.run_attempt:'';
  const jobList=selected && selected.status==='completed' && selected.conclusion==='success'
    ? request(prefix+'actions/runs/'+selected.id+attempt+'/jobs?per_page=100').jobs : [];
  const verdict=decide(pr,runs,jobList);
  console.log(JSON.stringify({pr:number,...verdict,runUrl:verdict.runId?
    'https://github.com/'+repo+'/actions/runs/'+verdict.runId:null},null,2));
  if (!verdict.ready){process.exitCode=1;return;}
  if(argv[1]!=='--merge') return;
  if(expectedBase && request(prefix+'git/ref/heads/main').object.sha!==expectedBase) {
    throw Error('main a change avant le squash : aucune fusion');
  }
  // GitHub compare le SHA au moment precis de la fusion : un nouveau commit bloque.
  const result=request(prefix+'pulls/'+number+'/merge','PUT',[
    '-f','sha='+verdict.sha,'-f','merge_method=squash']);
  if (!result.merged) throw Error('GitHub a refuse la fusion');
  console.log('Fusion '+result.sha+' : verifier une seule fois le run push main sur ce SHA.');
}
if(require.main===module){
  try{main();}catch(e){console.error('Aucune fusion : '+e.message);process.exitCode=1;}
}
module.exports={decide,main};
