'use strict';
const assert=require('node:assert/strict');
const {analyze,report}=require('../ci/ci-history-metrics.cjs');
function sample(id,durationSeconds,s1,s2){
 const start='2026-11-03T00:00:00Z',end=new Date(Date.parse(start)+durationSeconds*1000).toISOString();
 const jobs=Array.from({length:5},(_,i)=>({name:'Suites '+(i+1)+'/5',status:'completed',conclusion:'success',log:i===0?'PASS tests/slow.cjs ('+s1+' s)\nPASS tests/quick.cjs ('+s2+' s)':'PASS tests/extra'+i+'.cjs (1 s)'}));
 jobs.push({name:'classification',status:'completed',conclusion:'success'},{name:'Validation CI',status:'completed',conclusion:'success'});
 return {id,name:'Tests JavaScript',status:'completed',conclusion:'success',sha:'sha'+id,started_at:start,completed_at:end,jobs};
}
const a=analyze([sample(1,100,20,2),sample(2,130,40,4),sample(3,110,30,3)]);
assert.equal(a.runs,3);assert.equal(a.medianCI,110);assert.equal(a.p90CI,130);
assert.equal(a.partialSuites,0);assert.equal(a.slowest[0].name,'tests/slow.cjs');
assert.equal(a.slowest[0].p90,40);assert.match(report(a),/P90 130 s/);
assert.throws(()=>analyze([sample(1,100,20,2)]),/Au moins deux/);
assert.throws(()=>analyze([sample(1,100,20,2),sample(1,110,30,3)]),/dupliqué/);
const red=sample(2,110,30,3);red.jobs[6].conclusion='failure';
assert.throws(()=>analyze([sample(1,100,20,2),red]),/7 jobs SUCCESS/);
const missing=sample(2,110,30,3);delete missing.jobs[0].log;
assert.throws(()=>analyze([sample(1,100,20,2),missing]),/Log shard manquant/);
const mixed=sample(2,110,30,3);mixed.jobs[0].log='PASS tests/slow.cjs (30 s)';
const m=analyze([sample(1,100,20,2),mixed]);assert.equal(m.partialSuites,1);
console.log('ci-history-metrics PASS');
