'use strict';
const assert=require('node:assert/strict');const api=require('../dist/reputation.js');
assert.equal(api.reputationTier(85),'élite');assert.equal(api.recruitmentReach({clubReputation:50,playerReputation:65}).reachable,false);assert.equal(api.recruitmentReach({clubReputation:50,playerReputation:60}).reachable,true);
console.log('V47 : contrôles avancés réussis');
