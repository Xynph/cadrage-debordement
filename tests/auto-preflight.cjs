'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {candidates,seven,eligible,summary}=require('../ci/auto-preflight.cjs');
const sha='a'.repeat(40),other='b'.repeat(40);
const run={id:99,name:'Tests JavaScript',event:'pull_request',status:'completed',conclusion:'success',
 head_sha:sha,pull_requests:[{number:301,base:{ref:'main'},head:{sha}}]};
const event=()=>({action:'completed',workflow_run:structuredClone(run)});
const names=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
const jobs=names.map(name=>({name,status:'completed',conclusion:'success'}));
const pr={state:'open',base:{ref:'main'},head:{sha,repo:{full_name:'Xynph/cadrage-debordement'}},draft:false,mergeable:true,mergeable_state:'clean'};
test('CI PR exacte seulement, aucune autre action',()=>{
 assert.deepEqual(candidates(event()),[301]);
 for(const change of [e=>e.action='requested',e=>e.workflow_run.conclusion='failure',
   e=>e.workflow_run.event='push',e=>e.workflow_run.head_sha=other,
   e=>e.workflow_run.pull_requests[0].head.sha=other,
   e=>e.workflow_run.pull_requests[0].base.ref='other']){
  const e=event();change(e);assert.deepEqual(candidates(e),[]);
 }
 assert.deepEqual(candidates({}),[]);
});
test('7 jobs terminaux et uniques exigés',()=>{
 assert.equal(seven(jobs),true);
 assert.equal(seven(jobs.slice(1)),false);
 assert.equal(seven([...jobs,jobs[0]]),false);
 for(const name of names){const copy=structuredClone(jobs);copy.find(x=>x.name===name).conclusion='skipped';assert.equal(seven(copy),false);}
});
test('PR strictement READY propre sur HEAD exact',()=>{
 assert.equal(eligible(pr,sha),true);
 for(const change of [p=>p.draft=true,p=>p.mergeable=false,p=>p.mergeable_state='dirty',
   p=>p.head.sha=other,p=>p.base.ref='other',p=>p.state='closed',
   p=>p.head.repo.full_name='unknown/repo']){const p=structuredClone(pr);change(p);assert.equal(eligible(p,sha),false);}
});
test('CI 7/7 puis gate officiel sans fusion',()=>{
 const calls=[],get=path=>{calls.push(path);return path.startsWith('actions/')?{jobs}:pr;};
 const out=summary(event(),get,(n,s)=>{calls.push('gate '+n+' '+s);return 'ready';});
 assert.match(out,/gate officiel vert/);assert.match(out,/Fusion \*\*non effectuée\*\*/);
 assert.deepEqual(calls,['actions/runs/99/jobs?per_page=100','pulls/301','gate 301 '+sha]);
});
test('aucun gate si run incomplet, PR non propre ou CI rouge',()=>{
 let calls=0;
 const gate=()=>{calls++;};
 assert.match(summary(event(),p=>p.startsWith('actions/')?{jobs:jobs.slice(0,6)}:pr,gate),/non confirmée/);
 assert.match(summary(event(),p=>p.startsWith('actions/')?{jobs}:{...pr,draft:true},gate),/gate non appelé/);
 assert.equal(calls,0);
});
test('refus du gate reste un diagnostic sans livraison',()=>{
 const out=summary(event(),path=>path.startsWith('actions/')?{jobs}:pr,()=>{throw Error('refus');});
 assert.match(out,/bloquant/);assert.match(out,/non effectuée/);
});
test('workflow sans permission écriture ni checkout de code PR',()=>{
 const fs=require('node:fs'),path=require('node:path');
 const y=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-preflight.yml'),'utf8');
 assert.match(y,/workflow_run:/);assert.match(y,/types: \[completed\]/);
 assert.match(y,/^permissions: \{\}/m);assert.match(y,/pull-requests: read/);
 assert.match(y,/ref: \$\{\{ github.event.repository.default_branch \}\}/);
 assert.match(y,/persist-credentials: false/);
 assert(!y.includes('pull_request_target'));assert(!y.includes('contents: write'));
 assert(!y.includes('/cd-merge'));assert(!y.includes('secrets.'));
});
