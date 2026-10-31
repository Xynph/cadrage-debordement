'use strict';
const assert=require('node:assert/strict');const api=require('../dist/rugby-world.js');
const players=[{id:'x',rating:80,minutes:1000,tries:4}];const p=api.seasonAwards(Array.from({length:12},()=>players));assert.equal(p.length,12);assert.equal(p[11].winners[0].id,'x');assert.equal(players[0].rating,80);assert.throws(()=>api.seasonAwards(Array(41).fill(players)));
console.log('V50 — scénario pluriannuel : OK');
