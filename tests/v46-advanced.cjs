'use strict';
const assert=require('node:assert/strict');const api=require('../dist/club-ai.js');
assert.equal(api.squadCoverage({players:[{pos:'Pilier',injury:0},{pos:'Pilier',injury:2}],required:{Pilier:2}})[0].shortage,1);assert.throws(()=>api.squadCoverage({players:[],required:{Pilier:-1}}));
console.log('V46 : contrôles avancés réussis');
