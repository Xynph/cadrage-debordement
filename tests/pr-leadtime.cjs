'use strict';
const assert=require('node:assert/strict');
const {median,percentile,summarize,formatReport}=require('../ci/pr-leadtime.cjs');
assert.equal(median([]),null);
assert.equal(median([7,1,5]),5);
assert.equal(median([2,8]),5);
assert.equal(percentile([1,2,3,4,5],.9),5);
const prs=[
 {number:3,state:'closed',created_at:'2026-11-03T00:00:00Z',merged_at:'2026-11-03T00:06:00Z'},
 {number:1,state:'closed',created_at:'2026-11-03T00:00:00Z',merged_at:'2026-11-03T00:30:00Z'},
 {number:2,state:'open',created_at:'2026-11-03T00:00:00Z',merged_at:null}
];
const report=summarize(prs,3,new Date('2026-11-03T01:00:00Z'));
assert.equal(report.sample,3);
assert.equal(report.merged,2);
assert.equal(report.unmerged,1);
assert.equal(report.medianMinutes,18);
assert.equal(report.p90Minutes,30);
assert.equal(report.rows[0].number,3);
assert.equal(summarize(prs,1).merged,1);
assert.match(formatReport(report),/Ne mesure PAS/);
assert.throws(()=>summarize(null),TypeError);
assert.throws(()=>summarize(prs,0),RangeError);
console.log('PASS pr-leadtime');
