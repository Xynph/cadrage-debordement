'use strict';
const assert=require('node:assert/strict');const api=require('../dist/facilities.js');
const p=api.investmentSchedule({cash:12000,level:8,projects:[{cost:2000,weeks:1},{cost:2000,weeks:1},{cost:2000,weeks:1}]});assert.equal(p.level,10);assert.deepEqual(p.steps.map(x=>x.approved),[true,true,false]);assert.equal(p.remaining,8000);
console.log('V49 — scénario pluriannuel : OK');
