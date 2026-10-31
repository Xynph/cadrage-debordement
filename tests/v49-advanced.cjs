'use strict';
const assert=require('node:assert/strict');const api=require('../dist/facilities.js');
const q=api.maintenanceForecast({cash:5000,levels:[2,4],weeks:10,baseWeekly:100});assert.equal(q.weekly,290);assert.equal(q.remaining,2100);assert.throws(()=>api.maintenanceForecast({cash:1,levels:[11]}));
console.log('V49 : contrôles avancés réussis');
