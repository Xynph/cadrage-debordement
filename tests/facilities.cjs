'use strict';
const assert=require('node:assert/strict');const api=require('../dist/facilities.js');
assert.equal(api.investment({cash:10000,level:3,cost:8000,weeklyMaintenance:100,weeks:26}).affordable,false);assert.equal(api.investment({cash:10000,level:10,cost:1000}).atMaximum,true);
console.log('V49 : tests ciblés réussis');
