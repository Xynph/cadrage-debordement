'use strict';
const assert=require('node:assert/strict');const api=require('../dist/rugby-world.js');
assert.deepEqual(api.rivalry('a','b',[{home:'a',away:'b',homeScore:10,awayScore:5}]).winsA,1);assert.equal(api.awards([{id:'a',rating:80,minutes:800,tries:2}])[0].id,'a');
console.log('V50 : tests ciblés réussis');
