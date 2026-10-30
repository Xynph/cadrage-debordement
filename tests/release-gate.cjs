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
