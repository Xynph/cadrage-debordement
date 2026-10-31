'use strict';
const assert=require('node:assert/strict');const api=require('../dist/reputation.js');
assert.ok(api.update({current:50,leagueFinish:1,leagueSize:14,champion:true}).next>50);assert.ok(api.update({current:50,leagueFinish:14,leagueSize:14,financeHealthy:false}).next<50);
console.log('V47 : tests ciblés réussis');
