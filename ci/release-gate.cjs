'use strict';
// Bilan unique et fusion volontaire : aucune boucle de polling.
// Usage : node ci/release-gate.cjs <numero-pr> [--merge]
// Prerequis : gh auth login, acces au depot et droits de fusion.
const {execFileSync}=require('node:child_process');
const repo=process.env.CD_REPO || 'Xynph/cadrage-debordement';

function decide(pr,runs,jobs) {
  if (!pr || pr.state !== 'open' || pr.base?.ref !== 'main' || !pr.head?.sha ||
      pr.head.repo?.full_name !== repo || pr.draft ||
      pr.mergeable !== true || pr.mergeable_state !== 'clean') {
    return {ready:false,reason:'PR non fusionnable, base invalide ou etat incertain'};
  }
  const sha=pr.head.sha;
  const matches=(runs||[]).filter(run=>run.event==='pull_request' &&
    run.head_sha===sha && run.name==='Tests JavaScript');
  matches.sort((a,b)=>new Date(b.created_at)-new Date(a.created_at));
  const run=matches[0];
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
function main(argv=process.argv.slice(2)) {
  if (argv.length<1 || argv.length>2 || !/^\d+$/.test(argv[0]) ||
      (argv[1] && argv[1]!=='--merge')) {
    console.error('Usage : node ci/release-gate.cjs <PR> [--merge]');
    process.exitCode=2;return;
  }
  const number=Number(argv[0]);
  const pr=api('repos/'+repo+'/pulls/'+number);
  const expected=process.env.CD_EXPECTED_HEAD_SHA;
  if(expected && (!/^[0-9a-f]{40}$/.test(expected) || pr.head?.sha!==expected)) {
    throw Error('SHA attendu different de la tete de PR : aucune fusion');
  }
  if (pr.state!=='open' || !pr.head?.sha) {
    console.log('PR fermee ou sans SHA : aucune fusion');process.exitCode=1;return;
  }
  const all=api('repos/'+repo+'/actions/workflows/tests.yml/runs?event=pull_request&per_page=50');
  const runs=all.workflow_runs||[];
  const selected=runs.filter(x=>x.head_sha===pr.head.sha &&
      x.event==='pull_request' && x.name==='Tests JavaScript')
    .sort((a,b)=>new Date(b.created_at)-new Date(a.created_at))[0];
  const jobList=selected && selected.status==='completed' && selected.conclusion==='success'
    ? api('repos/'+repo+'/actions/runs/'+selected.id+'/jobs?per_page=100').jobs : [];
  const verdict=decide(pr,runs,jobList);
  console.log(JSON.stringify({pr:number,...verdict,runUrl:verdict.runId?
    'https://github.com/'+repo+'/actions/runs/'+verdict.runId:null},null,2));
  if (!verdict.ready){process.exitCode=1;return;}
  if(argv[1]!=='--merge') return;
  // GitHub compare le SHA au moment precis de la fusion : un nouveau commit bloque.
  const result=api('repos/'+repo+'/pulls/'+number+'/merge','PUT',[
    '-f','sha='+verdict.sha,'-f','merge_method=squash']);
  if (!result.merged) throw Error('GitHub a refuse la fusion');
  console.log('Fusion '+result.sha+' : verifier une seule fois le run push main sur ce SHA.');
}
if(require.main===module){
  try{main();}catch(e){console.error('Aucune fusion : '+e.message);process.exitCode=1;}
}
module.exports={decide};
