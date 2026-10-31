'use strict';
const assert=require('node:assert/strict');const api=require('../dist/coach-market.js');
assert.deepEqual(api.vacancies([{id:'a',vacant:true,budget:5000,reputation:60}],[{id:'x',salary:3000,reputation:65,available:true}])[0].options,['x']);assert.equal(api.dismissalRisk({confidence:10,consecutiveLosses:4}).critical,true);
console.log('V48 : tests ciblés réussis');
