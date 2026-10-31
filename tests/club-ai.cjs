'use strict';
const assert=require('node:assert/strict');const api=require('../dist/club-ai.js');
assert.equal(api.decideClub({cash:1000000,wageRoom:5000,needs:['Pilier'],candidates:[{id:'p1',pos:'Pilier',fee:200000,wage:2000,rating:78}]}).candidate.id,'p1');assert.equal(api.decideClub({cash:0,wageRoom:0,needs:['Pilier'],candidates:[]}).action,'conserve');
console.log('V46 : tests ciblés réussis');
