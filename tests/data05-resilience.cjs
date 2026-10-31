'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {classify,validateCache,withRetries,reserveBudget}=require('../tools/data05-resilience.cjs');
test('rate limit and auth stop; 5xx retry',()=>{for(const status of [401,403,429,402])assert.equal(classify({status}).stop,true);assert.equal(classify({status:503}).retry,true)});
test('bounded exponential retry',async()=>{let n=0;const delays=[];const x=await withRetries(async()=>{if(n++<2)throw {status:503};return 'ok'},{wait:async ms=>delays.push(ms)});assert.equal(x,'ok');assert.deepEqual(delays,[250,500])});
test('strict budget and identity checks',()=>{const count={used:0};assert.equal(reserveBudget(count,1),true);assert.equal(reserveBudget(count,1),false);assert.equal(count.used,1);const ref={id:'lnr:862',club:'clermont',url:'https://top14.lnr.fr/joueur/862-barnabe-massa'};assert.equal(validateCache({...ref,name:'Name',birthDate:null,validAtJuly1:false},ref),true);assert.throws(()=>validateCache({...ref,name:'Name',birthDate:'2000-01-01',validAtJuly1:false},ref))});
