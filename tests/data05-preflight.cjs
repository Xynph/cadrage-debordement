'use strict';
const test=require('node:test'),assert=require('node:assert/strict');const {validatePlan,checkCache}=require('../tools/data05-preflight.cjs');
test('dry run 240 profiles zero cost',()=>assert.deepEqual(validatePlan({cached:240}),{catalogue:1592,cached:240,remaining:1352,planned:0,firecrawlMaximumAttempts:0,dryRun:true}));
test('reject unsafe rate, paid budgets and unconfirmed network',()=>{assert.throws(()=>validatePlan({cached:240,limit:1}),/confirmation/);assert.throws(()=>validatePlan({cached:240,limit:1,budget:2,confirmed:true}),/budget/);assert.throws(()=>validatePlan({concurrency:3}),/rate/)});
test('reject duplicate and wrong-url cached players',()=>{const r=[{id:'lnr:1',url:'https://top14.lnr.fr/joueur/1-test',club:'clermont'}],p={...r[0],name:'Test'};assert.equal(checkCache([p],r).valid,1);assert.throws(()=>checkCache([p,p],r),/Invalid cached/);assert.throws(()=>checkCache([{...p,url:'bad'}],r),/Invalid cached/)});
