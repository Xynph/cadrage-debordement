'use strict';
const assert=require('node:assert/strict');const api=require('../dist/rugby-world.js');
const h=api.headToHeadTable(['a','b'],[{home:'a',away:'b',homeScore:20,awayScore:10},{home:'b',away:'a',homeScore:5,awayScore:5}]);assert.equal(h[0].clubId,'a');assert.equal(h[0].won,1);assert.equal(h[1].drawn,1);
console.log('V50 : contrôles avancés réussis');
