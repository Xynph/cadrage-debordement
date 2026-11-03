'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {validateTrigger,safePath,validateCandidate,latestRuns,runAuto}=require('../ci/auto-release.cjs');
const sha='a'.repeat(40),main='b'.repeat(40),repo='Xynph/cadrage-debordement';
const env={GITHUB_EVENT_NAME:'workflow_run',GITHUB_REPOSITORY:repo,GITHUB_SHA:main,CD_AUTO_RELEASE_ENABLED:'true'};
const event=()=>({action:'completed',repository:{full_name:repo},workflow_run:{id:42,name:'Tests JavaScript',event:'pull_request',status:'completed',conclusion:'success',head_sha:sha,pull_requests:[{number:271}]}});
const pr=()=>({state:'open',draft:false,base:{ref:'main',sha:main},head:{sha,repo:{full_name:repo}},user:{login:'Xynph',id:350229047,type:'User'},mergeable:true,mergeable_state:'clean',changed_files:2});
const files=()=>[{filename:'dist/ui03-scout-components.js',status:'modified'},{filename:'tests/scouting.cjs',status:'added'}];
test('disabled by default',()=>assert.throws(()=>validateTrigger(event(),{...env,CD_AUTO_RELEASE_ENABLED:''}),/flag/));
test('valid exact CI event',()=>assert.equal(validateTrigger(event(),env).pr,271));
test('terminal ancillary CI may retrigger when all runs are green',()=>{const e=event();e.workflow_run.name='UI Chromium mutualise - CI V3';assert.equal(validateTrigger(e,env).sourceName,'UI Chromium mutualise - CI V3');});
for(const [name,fn] of [
 ['multiple PR',e=>e.workflow_run.pull_requests.push({number:272})],
 ['missing PR',e=>e.workflow_run.pull_requests=[]],
 ['failure',e=>e.workflow_run.conclusion='failure'],
 ['non PR',e=>e.workflow_run.event='push'],
 ['wrong workflow',e=>e.workflow_run.name='Other'],
 ['wrong action',e=>e.action='requested'],
 ['bad SHA',e=>e.workflow_run.head_sha='123']])
 test('reject '+name,()=>{const e=event();fn(e);assert.throws(()=>validateTrigger(e,env));});
test('strict file policy',()=>{
 for(const p of ['docs/a.md','tests/a.cjs','dist/ui03-scout-components.js','dist/v17-view.js','dist/style.css'])assert(safePath({filename:p,status:'modified'}),p);
 for(const p of ['.github/workflows/tests.yml','ci/release-gate.cjs','dist/storage.js','dist/rugby.js','dist/tactical-plans.js','modding/data06/rugby-master-2026-2027.json','AGENTS.md','docs/../ci/evil.md'])assert(!safePath({filename:p,status:'modified'}),p);
 assert(!safePath({filename:'docs/a.md',status:'removed'}));
});
test('clean owner PR with tested UI',()=>assert(validateCandidate(pr(),files(),sha,main)));
for(const [name,fn] of [['draft',p=>p.draft=true],['fork',p=>p.head.repo.full_name='other/repo'],['non-owner',p=>p.user.id=99],['conflict',p=>p.mergeable_state='dirty'],['old main',p=>p.base.sha=sha],['old head',p=>p.head.sha=main],['missing files',p=>p.changed_files=1]])
 test('reject '+name,()=>{const p=pr();fn(p);assert.throws(()=>validateCandidate(p,files(),sha,main));});
test('source JS requires test',()=>assert.throws(()=>validateCandidate({...pr(),changed_files:1},[files()[0]],sha,main),/test/));
test('sensitive file denied',()=>assert.throws(()=>validateCandidate({...pr(),changed_files:1},[{filename:'ci/release-gate.cjs',status:'modified'}],sha,main)));
const run=(id,name='Tests JavaScript',status='completed',conclusion='success')=>({id,name,status,conclusion,head_sha:sha,event:'pull_request'});
test('stale or pending CI denied',()=>{
 assert(latestRuns([run(42),run(40,'Chromium')],sha,42));
 assert.throws(()=>latestRuns([run(42),run(44,'Tests JavaScript','completed','failure')],sha,42));
 assert.throws(()=>latestRuns([run(42),run(44,'Chromium','in_progress',null)],sha,42));
});
test('delegates only to guarded release engine',async()=>{
 const names=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];let called=false;
 const api=p=>{
  if(p==='git/ref/heads/main')return {object:{sha:main}};
  if(p==='pulls/271')return pr();
  if(p==='pulls/271/files?per_page=100')return files();
  if(p==='actions/workflows/tests.yml')return {id:7,state:'active'};
  if(p==='actions/runs/42')return {...run(42),workflow_id:7};
  if(p==='actions/runs/42/jobs?per_page=100')return {jobs:names.map(name=>({name,status:'completed',conclusion:'success'}))};
  if(p.startsWith('actions/runs?'))return {workflow_runs:[{...run(42),workflow_id:7}]};
  throw Error('Unexpected '+p);
 };
 const result=await runAuto(event(),env,{api,execute:async(c,e,d)=>{called=true;assert.equal(c.expected,sha);assert(d.autoAuthorized);assert.equal(d.snapshot,main);return {ready:true};}});
 assert(called);assert.deepEqual(result,{ready:true});
});
test('workflow pinned main and disabled without repo variable',()=>{
 const fs=require('node:fs'),path=require('node:path'),y=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-release.yml'),'utf8');
 assert.match(y,/CD_AUTO_RELEASE_ENABLED/);assert.match(y,/group: chat-release-gate-main/);
 assert.match(y,/persist-credentials: false/);assert.match(y,/ref: \$\{\{ github.sha \}\}/);
 assert(!y.includes('pull_request_target'));
 for(const m of y.matchAll(/uses: (\S+)/g))assert.match(m[1],/@[a-f0-9]{40}$/);
});
