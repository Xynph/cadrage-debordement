'use strict';
const assert=require('node:assert/strict');const api=require('../dist/club-ai.js');
const p=api.planSeason({cash:1000000,wageRoom:4000,needs:['Pilier','Centre'],candidates:[{id:'a',pos:'Pilier',fee:100000,wage:2000,rating:80},{id:'b',pos:'Centre',fee:100000,wage:2000,rating:75}]});assert.equal(p.targets.length,2);assert.equal(p.remainingCash,800000);assert.equal(p.seasonWages,104000);assert.equal(api.planSeason({cash:0,wageRoom:0}).targets.length,0);
console.log('V46 — scénario pluriannuel : OK');
