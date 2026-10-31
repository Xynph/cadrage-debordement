'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {runProtected}=require('../tools/data05-wired.cjs');
test('limits rejected before network',async()=>{await assert.rejects(runProtected({budget:-1}),/Invalid collection limit/);await assert.rejects(runProtected({limit:-1}),/Invalid collection limit/)});
test('fail closed without resilience dependency #134',async()=>{try{require.resolve('../tools/data05-resilience.cjs')}catch{await assert.rejects(runProtected({limit:0,budget:0}),/PR #134 resilience module not integrated/);return}assert.ok(true)});
