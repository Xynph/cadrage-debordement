'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {CI_JOBS,latest,evaluate,inspect,render,ghRead}=require('../ci/development-snapshot.cjs');
const R='Xynph/cadrage-debordement',a='a'.repeat(40),b='b'.repeat(40),c='c'.repeat(40);
const jobs=()=>CI_JOBS.map(name=>({name,status:'completed',conclusion:'success'}));
const run=(id,w=10,name='Tests JavaScript',status='completed',conclusion='success')=>({
 id,workflow_id:w,name,path:w===10?'.github/workflows/tests.yml':'.github/workflows/special.yml',
 event:'pull_request',head_sha:b,created_at:'2026-11-02T08:00:'+String(id).padStart(2,'0')+'Z',
 updated_at:'2026-11-02T08:00:'+String(id).padStart(2,'0')+'Z',status,conclusion
});
const pr=()=>({number:207,state:'open',draft:false,mergeable:true,mergeable_state:'clean',
 base:{ref:'main',sha:a,repo:{full_name:R}},head:{sha:b,repo:{full_name:R}}});
function fixture(){return {pr:pr(),main:a,collection:{total_count:2,workflow_runs:[run(2),run(3,20,'Chromium')]},jobs:jobs(),reads:4};}
test('snapshot quatre GET, sans mutation, passation concise',()=>{
 const x=fixture(),calls=[];
 const api=p=>{
  calls.push(p);
  if(p==='git/ref/heads/main')return {object:{sha:a}};
  if(p==='pulls/207')return x.pr;
  if(p.startsWith('actions/runs?'))return x.collection;
  if(p==='actions/runs/2/jobs?per_page=100')return {jobs:x.jobs};
  throw Error('Requête inattendue '+p);
 };
 const s=inspect(207,api);
 assert.equal(s.status,'CONTROLE_POSSIBLE');assert.equal(s.reads,4);assert.equal(calls.length,4);
 assert(calls.every(p=>!/(?:\/merge|\/dispatches|\/comments|\/rerun)/.test(p)));
 assert.match(render(s,true),/PASSATION CANDIDATE/);
 assert(!render(s).includes('/cd-merge'));
});
test('dernière CI rouge prime sur ancienne CI verte',()=>{
 const x=fixture();x.collection.workflow_runs.push(run(4,10,'Tests JavaScript','completed','failure'));x.collection.total_count=3;
 assert.equal(evaluate(x).status,'STOP');
});
test('échec spécial, CI rouge ou job ignoré et doublé bloquent',()=>{
 for(const change of [
  x=>x.collection.workflow_runs[1].conclusion='failure',
  x=>x.collection.workflow_runs[0].conclusion='failure',
  x=>x.jobs.pop(),
  x=>x.jobs[2].conclusion='skipped',
  x=>x.jobs.push({...x.jobs[0]})
 ]){
  const x=fixture();change(x);assert.equal(evaluate(x).status,'STOP');
 }
});
test('CI et fusionabilité en cours restent en attente',()=>{
 const x=fixture();x.collection.workflow_runs[0].status='in_progress';
 assert.equal(evaluate(x).status,'EN_ATTENTE');
 const y=fixture();y.pr.mergeable_state='unknown';
 assert.equal(evaluate(y).status,'EN_ATTENTE');
});
test('ancien main, fork, brouillon, conflit et page tronquée refusés',()=>{
 for(const change of [
  x=>x.pr.base.sha=c,x=>x.pr.head.repo.full_name='other/repo',
  x=>x.pr.base.ref='other',x=>x.pr.mergeable=false,x=>x.pr.mergeable_state='dirty',
  x=>x.pr.state='closed',x=>x.pr.draft=true,x=>x.collection.total_count=101
 ]){
  const x=fixture();change(x);assert.equal(evaluate(x).status,'STOP');
 }
 const bad=fixture();bad.main='invalid';assert.throws(()=>evaluate(bad));
});
test('runs étrangers ignorés, absence de CI refusée',()=>{
 const x=fixture();x.collection.workflow_runs=[run(3,20,'Chromium')];x.collection.total_count=1;
 assert.equal(evaluate(x).status,'STOP');
 assert.equal(latest([run(1),{...run(2),head_sha:c},{...run(3),event:'workflow_dispatch'}],b).length,1);
 assert.throws(()=>inspect(0,()=>{}));assert.throws(()=>inspect(-1,()=>{}));
});
test('transport API refuse toute écriture et endpoint non prévu',()=>{
 for(const endpoint of ['issues/73/comments','pulls/207/merge',
  'actions/workflows/tests.yml/dispatches','actions/runs/1/rerun',
  'actions/runs?event=pull_request&head_sha=x&per_page=100'])
  assert.throws(()=>ghRead(endpoint),/non autorisé/);
});
