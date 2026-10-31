'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {audit,dryRun}=require('../tools/data05-audit.cjs');
test('actual committed LNR roster and 15 data batches agree',()=>{
 const r=audit();assert.equal(r.catalogue,1592);assert.equal(r.uniqueImportedCandidates,240);assert.equal(r.remaining,1352);
 assert.deepEqual(r.counts,{'data05-bulk':90,'data05-bulk2':60,'data05-bulk3':90});
});
test('zero-budget dry-run imports exactly 240 and exports exactly 240 without HTTP',async()=>{
 const r=await dryRun();assert.equal(r.dryRunImported,240);assert.equal(r.dryRunApiCalls,0);assert.equal(r.exported,240);
});
