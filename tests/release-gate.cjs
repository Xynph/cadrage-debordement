'use strict';
const assert=require('node:assert/strict');
const {decide}=require('../ci/release-gate.cjs');
const repo='Xynph/cadrage-debordement';
const pr={state:'open',base:{ref:'main'},head:{sha:'a'.repeat(40),repo:{full_name:repo}},
  draft:false,mergeable:true,mergeable_state:'clean'};
const run={id:100,name:'Tests JavaScript',event:'pull_request',
  head_sha:pr.head.sha,status:'completed',conclusion:'success',created_at:'2026-10-30T23:00:00Z'};
const jobs=[{name:'Validation CI',status:'completed',conclusion:'success'}];
assert.equal(decide(pr,[run],jobs).ready,true);
const reject=(p,r,j)=>assert.equal(decide(p,r,j).ready,false);
reject({...pr,draft:true},[run],jobs);
reject({...pr,mergeable_state:'dirty'},[run],jobs);
reject({...pr,base:{ref:'other'}},[run],jobs);
reject({...pr,head:{...pr.head,sha:'b'.repeat(40)}},[run],jobs);
reject(pr,[{...run,status:'in_progress'}],jobs);
reject(pr,[{...run,conclusion:'failure'}],jobs);
reject(pr,[{...run,event:'push'}],jobs);
reject(pr,[run],[{...jobs[0],conclusion:'failure'}]);
reject(pr,[run],[]);
reject(pr,[],jobs);
reject(pr,[{...run,created_at:'2026-10-30T22:00:00Z'},{...run,id:101,conclusion:'failure'}],jobs);
console.log('release-gate: 12 scenarios verifies');

const {main}=require('../ci/release-gate.cjs');
const expectedBase='b'.repeat(40);
const candidate={...pr,base:{ref:'main',sha:expectedBase}};
const checkedRun={...run,run_attempt:2};
const scopedEnv={
 CD_EXPECTED_HEAD_SHA:pr.head.sha,CD_EXPECTED_BASE_SHA:expectedBase,
 CD_EXPECTED_CI_RUN:'100',CD_EXPECTED_CI_ATTEMPT:'2'
};
function scopedGate({current=expectedBase,runs=[checkedRun]}={}){
 const calls=[];
 const api=(endpoint,method='GET',args)=>{
  calls.push({endpoint,method,args});
  if(endpoint==='repos/'+repo+'/pulls/100')return candidate;
  if(endpoint==='repos/'+repo+'/git/ref/heads/main')return {object:{sha:current}};
  if(endpoint==='repos/'+repo+'/actions/workflows/tests.yml/runs?event=pull_request&head_sha='+pr.head.sha+'&per_page=100')
   return {total_count:runs.length,workflow_runs:runs};
  if(endpoint==='repos/'+repo+'/actions/runs/100/attempts/2/jobs?per_page=100')return {jobs};
  if(endpoint==='repos/'+repo+'/pulls/100/merge')return {merged:true,sha:'c'.repeat(40)};
  throw Error('Unexpected '+endpoint);
 };
 return {calls,merge:()=>main(['100','--merge'],api,scopedEnv)};
}
{
 const gate=scopedGate();
 gate.merge();
 assert.deepEqual(gate.calls.at(-1),{
  endpoint:'repos/'+repo+'/pulls/100/merge',method:'PUT',args:['-f','sha='+pr.head.sha,'-f','merge_method=squash']
 });
}
for(const options of [{current:'c'.repeat(40)},{runs:[{...checkedRun,run_attempt:3}]},
 {runs:[checkedRun,{...checkedRun,id:101,status:'in_progress'}]}]){
 const gate=scopedGate(options);
 assert.throws(gate.merge,/main|CI/);
 assert.equal(gate.calls.some(x=>x.method==='PUT'),false);
}
