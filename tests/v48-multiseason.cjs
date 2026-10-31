'use strict';
const assert=require('node:assert/strict');const api=require('../dist/coach-market.js');
const p=api.forecastRisk({confidence:60,lossesBySeason:[0,1,6,7,2,1]});assert.equal(p.history.length,6);assert.ok(p.confidence>=0&&p.confidence<=100);assert.throws(()=>api.forecastRisk({confidence:60,lossesBySeason:[-1]}));
console.log('V48 — scénario pluriannuel : OK');
