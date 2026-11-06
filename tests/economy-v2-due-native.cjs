'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs'),C=require('../dist/economy-v2-due-contract.js');
test('E2.5: 14 live clubs each retain a native save while liabilities remain unknown',()=>{
 for(const club of [0,6,13]){
  const g=N.fresh(club,827381),before=N.data(g,'createSaveDocument()');
  const preview=C.legacyPreview(before.state);
  assert.equal(preview.observedClubs,14);assert.equal(preview.legacyUnmeasuredLiabilities,null);
  assert.equal(preview.ledger.obligations.length,0);
  const after=N.data(g,'createSaveDocument()');
  assert.equal(before.checksum,after.checksum);assert.deepEqual(before.state,after.state);
 }
});
test('E2.5: native debt crisis is not automatically a payable invoice',()=>{
 const g=N.fresh();g.run('S.clubs[1].cash=-150000;worldClub(1).debt=500000;worldNewSeason()');
 const s=N.data(g),p=C.legacyPreview(s);
 assert.equal(p.ledger.obligations.length,0);
 assert.equal(p.ledger.payments.length,0);
 assert.equal(p.legacyUnmeasuredLiabilities,null);
 assert.ok(s.worldManagement.clubInfo[1].debt>=0);
});
