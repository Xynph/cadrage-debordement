'use strict';
const assert=require('node:assert/strict');const api=require('../dist/reputation.js');
const data=Array.from({length:12},()=>({leagueFinish:1,leagueSize:14,champion:true}));const p=api.simulateSeasons(50,data);assert.equal(p.history.length,12);assert.ok(p.current<=100);assert.equal(data[0].leagueFinish,1);assert.throws(()=>api.simulateSeasons(50,Array(41).fill({leagueFinish:1,leagueSize:14})));
console.log('V47 — scénario pluriannuel : OK');
