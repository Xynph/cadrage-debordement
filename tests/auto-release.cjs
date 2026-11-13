'use strict';

const {test}=require('node:test');
const assert=require('node:assert/strict');
const {runAuto}=require('../ci/auto-release.cjs');

const repo='Xynph/cadrage-debordement', repoId=1439603196;
const owner={id:350229047,login:'Xynph',type:'User'};
const head='a'.repeat(40), main='b'.repeat(40), other='c'.repeat(40), blob='d'.repeat(40);
const repository={full_name:repo,id:repoId};
const env={
 GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_REPOSITORY:repo,GITHUB_REF:'refs/heads/main',
 GITHUB_SHA:main,GITHUB_ACTOR:'Xynph',GITHUB_ACTOR_ID:'350229047',
 GITHUB_TRIGGERING_ACTOR:'Xynph',GITHUB_RUN_ATTEMPT:'1',CD_ORDINARY_MERGE_ENABLED:'true'
};
const event=(mode='check')=>({repository,sender:{...owner},inputs:{pr:'271',sha:head,mode}});
const file=(filename='docs/ui-presentation-exemple.md',status='added')=>({filename,status,sha:blob});
const jobs=(css=false)=>[
 {name:'classification',status:'completed',conclusion:'success'},
 {name:'Validation CI',status:'completed',conclusion:'success'},
 ...(css?require('../ci/ci-jobs.cjs').SHARD_JOBS.map(name=>({name,status:'completed',conclusion:'success'})):
 [{name:require('../ci/ci-jobs.cjs').SHARD_JOB_SKIPPED,status:'completed',conclusion:'skipped'}]),
 // Jobs Godot informatifs (continue-on-error) : ignorés par le décompte officiel.
 {name:'Godot 1/3',status:'completed',conclusion:'failure'}
];
const base={ref:'main',sha:main,repo:repository};
const pull=(number=271,sha=head)=>({
 number,state:'open',draft:false,base,head:{ref:'feature/ui',sha,repo:repository},
 user:owner,mergeable:true,mergeable_state:'clean',changed_files:1
});
const workflow=(name,id)=>({name,id,state:'active'});
const run=(workflowId=7,id=42)=>({
 id,name:workflowId===7?'Tests JavaScript':'UI Chromium mutualise - CI V3',
 workflow_id:workflowId,run_attempt:1,event:'pull_request',head_sha:head,head_branch:'feature/ui',
 status:'completed',conclusion:'success',pull_requests:[{number:271,head:pull().head,base}],
});
const rules=[
 {type:'pull_request',parameters:{allowed_merge_methods:['squash']}},
 {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,
  required_status_checks:[{context:'Validation CI',integration_id:15368}]}},
 {type:'deletion'},{type:'non_fast_forward'}
];

function fixture(options={}){
 const changed=options.changed||[file()];
 const css=changed.some(f=>f.filename.startsWith('dist/'));
 const selected={...pull(),changed_files:changed.length,...options.pr};
 const names=options.open||[selected];
 const calls=[];
 let lists=0;
 const api=(path,method='GET')=>{
  calls.push({path,method});
  assert.equal(method,'GET');
  if(path==='git/ref/heads/main')return {object:{sha:options.liveMain||main}};
  if(path==='rules/branches/main')return options.rules||rules;
  if(path==='pulls/271')return selected;
  if(path.startsWith('pulls?')){
   const page=Number(new URLSearchParams(path.split('?')[1]).get('page'));
   if(page===1)lists++;
   const rows=lists>1&&options.secondOpen||names;
   return rows.slice((page-1)*100,page*100);
  }
  if(path.startsWith('pulls/271/files?'))return changed;
  if(/^pulls\/\d+\/files\?/.test(path)){
   const number=Number(path.split('/')[1]);
   return options.concurrentFiles?.[number]||[file('dist/unrelated-'+number+'.js','modified')];
  }
  if(path==='git/trees/'+head)return {truncated:false,tree:[
   {path:'docs',type:'tree',mode:'040000',sha:'1'.repeat(40)},
   {path:'dist',type:'tree',mode:'040000',sha:'2'.repeat(40)}
  ]};
  if(/^git\/trees\/[12]{40}$/.test(path))return {truncated:false,tree:changed.map(f=>({
   path:f.filename.split('/')[1],sha:blob,type:'blob',mode:options.fileMode||'100644'
  }))};
  if(path==='actions/workflows/tests.yml')return workflow('Tests JavaScript',7);
  if(path==='actions/workflows/ui-browser-consolidated.yml')return workflow('UI Chromium mutualise - CI V3',8);
  if(path.startsWith('actions/runs?')){
   const visible=options.runs||[run(),...(css?[run(8,43)]:[])];
   return {total_count:visible.length,workflow_runs:visible};
  }
  if(path.startsWith('actions/runs/42/attempts/1/jobs?')){
   const list=options.jobs||jobs(css);
   return {jobs:list,total_count:list.length};
  }
  if(path.startsWith('actions/runs/43/attempts/1/jobs?')){
   const list=[{name:'UI — Chromium mutualisé (7 parcours)',status:'completed',conclusion:options.chromiumConclusion||'success'}];
   return {jobs:list,total_count:list.length};
  }
  throw Error('Unexpected API '+path);
 };
 return {
  calls, api,
  execute:async(cmd,e,d)=>{
   calls.push({gate:cmd,d});
   return cmd.mode==='check'?{ready:true}:{mergedSha:other,postRun:44,passed:true};
  }
 };
}

async function rejects(options={},message,dispatch=event('merge'),context=env){
 const f=fixture(options);
 await assert.rejects(()=>runAuto(dispatch,context,f),message);
 assert.equal(f.calls.filter(x=>x.gate).length,0);
}

test('contrôle sans flag possible, avec PR, tête et base transmises au gate',async()=>{
 const f=fixture();
 assert.deepEqual(await runAuto(event(),{...env,CD_ORDINARY_MERGE_ENABLED:''},f),{ready:true});
 const {gate,d}=f.calls.find(x=>x.gate);
 assert.deepEqual(gate,{pr:271,expected:head,mode:'check'});
 assert.equal(d.snapshot,main);
 assert.equal(d.autoAuthorized,true);
});

test('fusion explicite sur CSS autorisé avec CI JS complète et Chromium exact',async()=>{
 const f=fixture({changed:[file('dist/style.css','modified')]});
 assert.deepEqual(await runAuto(event('merge'),env,f),{mergedSha:other,postRun:44,passed:true});
 assert.equal(f.calls.find(x=>x.gate).gate.mode,'merge');
});

test('aucune fusion implicite, rejouée ou avec flag de l’ancien prototype',async()=>{
 await rejects({},/CD_ORDINARY_MERGE_ENABLED/,event('merge'),{...env,CD_ORDINARY_MERGE_ENABLED:'',CD_AUTO_RELEASE_ENABLED:'true'});
 await rejects({},/autorisé/,event('merge'),{...env,GITHUB_RUN_ATTEMPT:'2'});
 await rejects({},/autorisé/,event('merge'),{...env,GITHUB_EVENT_NAME:'workflow_run'});
 await rejects({},/autorisé/,event('merge'),{...env,GITHUB_TRIGGERING_ACTOR:'contributor'});
 await rejects({},/autorisé/,event('merge'),{...env,GITHUB_REF:'refs/heads/feature'});
 const forged=event('merge'); forged.sender.id=99;
 await rejects({},/autorisé/,forged);
 const malformed=event('merge'); malformed.inputs.sha=head+'\n';
 await rejects({},/sélection/,malformed);
});

test('tête, base, dépôt, auteur et état de PR sont revérifiés',async()=>{
 for(const patch of [
  {draft:true},{mergeable_state:'behind'},{state:'closed'},{user:{...owner,id:99}},
  {head:{...pull().head,sha:other}},{head:{...pull().head,repo:{id:3,full_name:'other/repo'}}},
  {base:{...base,sha:other}},{base:{...base,ref:'develop'}},{changed_files:2}
 ])await rejects({pr:patch},/PR|Diff/);
 await rejects({liveMain:other},/main/);
});

test('le ruleset strict et le contrôle GitHub Actions sont exigés',async()=>{
 await rejects({rules:rules.filter(x=>x.type!=='required_status_checks')},/Protection/);
 await rejects({rules:[...rules.slice(0,1),{type:'required_status_checks',parameters:{
  strict_required_status_checks_policy:false,required_status_checks:[{context:'Validation CI',integration_id:15368}]
 }},...rules.slice(2)]},/Protection/);
});

test('ni code ou chemins sensibles ni lien symbolique ou exécutable déguisé',async()=>{
 for(const f of [
  file('.github/workflows/tests.yml','modified'),file('dist/ui03-scout-components.js','modified'),
  file('docs/auto-release.md','modified'),file('dist/style.css','added'),
  file('docs/ui-presentation-exemple.md','renamed'),file('dist/finance-v2.css','modified')
 ])await rejects({changed:[f]},/hors périmètre/);
 for(const fileMode of ['120000','100755','160000'])await rejects({fileMode},/blob/);
});

test('analyse la deuxième page des PR et le nom d’origine d’un renommage',async()=>{
 const open=[pull(),...Array.from({length:125},(_,i)=>pull(300+i,other))];
 const f=fixture({open});
 assert.equal((await runAuto(event(),env,f)).ready,true);
 assert(f.calls.some(x=>x.path?.includes('page=2')));
 const rename={...file('docs/relocated.md','renamed'),previous_filename:'docs/ui-presentation-exemple.md'};
 await rejects({open,concurrentFiles:{423:[rename]}},/Chevauchement.*#423/);
 await rejects({open,secondOpen:open.map(p=>p.number===423?{...p,head:{...p.head,sha:blob}}:p)},/PR concurrentes ont changé/);
});

test('un résultat concurrent illisible bloque le gate',async()=>{
 const open=[pull(),pull(423,other)];
 await rejects({open,concurrentFiles:{423:[{status:'renamed',filename:'docs/relocated.md'}]}},/Diff concurrent/);
});

test('le verdict documentaire ne permet pas de sauter les suites CSS',async()=>{
 await rejects({changed:[file('dist/style.css','modified')],jobs:jobs()},/Jobs/);
 await rejects({jobs:jobs().slice(0,2)},/Jobs/);
});

test('la CI spécialisée nécessaire et le dernier verdict réussi sur la PR exacte sont exigés',async()=>{
 await rejects({changed:[file('dist/style.css','modified')],runs:[run()]},/Chromium/);
 await rejects({runs:[run(),{...run(7,46),status:'in_progress',conclusion:null}]},/CI PR/);
 await rejects({runs:[{...run(),pull_requests:[{...run().pull_requests[0],number:272}]}]},/CI PR/);
 await rejects({runs:[run(),{...run(99,46),conclusion:'failure'}]},/CI PR/);
 await rejects({runs:[{...run(),workflow_id:99}]},/Tests JavaScript/);
});


test('les brouillons restent à arbitrer par l’intégrateur, sans requête de diff',async()=>{
 const drafts=Array.from({length:115},(_,i)=>({...pull(300+i,other),draft:true}));
 const f=fixture({
  open:[pull(),...drafts],
  concurrentFiles:{415:[file()]}
 });
 assert.equal((await runAuto(event(),env,f)).ready,true);
 assert(!f.calls.some(x=>/^pulls\/(?!271)\d+\/files\?/.test(x.path||'')));
});

test('les chemins autorisés n’acceptent pas de saut de ligne dans leur nom',async()=>{
 await rejects({changed:[file('docs/ui-presentation-exemple.md\n')]},/hors périmètre/);
});

test('la CI et le job Chromium doivent réussir',async()=>{
 const css=[file('dist/style.css','modified')];
 await rejects({changed:css,runs:[run(),{...run(8,43),conclusion:'failure'}]},/CI PR/);
 await rejects({changed:css,chromiumConclusion:'skipped'},/Chromium/);
});

test('le workflow limite le jeton au mode et épingle le code de main',()=>{
 const fs=require('node:fs'),path=require('node:path');
 const yaml=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-release.yml'),'utf8');
 const [check,merge]=yaml.split(/^  merge:\s*$/m);
 assert.match(check,/workflow_dispatch:/);
 assert.doesNotMatch(yaml,/workflow_run:|pull_request_target:|issue_comment:|issues: write/);
 assert.doesNotMatch(check,/: write\s*$/m);
 assert.match(merge,/vars\.CD_ORDINARY_MERGE_ENABLED == 'true'/);
 assert.match(merge,/group: chat-release-gate-main/);
 for(const job of [check,merge]){
  assert.match(job,/github\.ref == 'refs\/heads\/main'/);
  assert.match(job,/github\.actor_id == '350229047'/);
  assert.match(job,/github\.run_attempt == 1/);
  assert.match(job,/ref: \$\{\{ github\.sha \}\}/);
  assert.match(job,/persist-credentials: false/);
  for(const action of job.matchAll(/uses: (\S+)/g))assert.match(action[1],/@[a-f0-9]{40}$/);
 }
});
