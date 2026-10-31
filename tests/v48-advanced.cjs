'use strict';
const assert=require('node:assert/strict');const api=require('../dist/coach-market.js');
assert.deepEqual(api.jobOffers([{id:'a',vacant:true,budget:7000,reputation:55},{id:'b',vacant:true,budget:1000,reputation:80}],{salary:4000,reputation:60}).map(x=>x.clubId),['a']);
console.log('V48 : contrôles avancés réussis');
