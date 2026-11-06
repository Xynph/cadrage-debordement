'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs'),O=require('./economy-v2-obligations.cjs');
test('E2.4: 14 observed club wages are exact, no fabricated booked liabilities',()=>{
 const s=O.snapshot(N.fresh()),x=O.contractEvidence(s);
 assert.equal(x.clubs.length,14);
 for(const row of x.clubs){
  const club=s.clubs.find(c=>c.id===row.clubId);
  assert.equal(row.weeklyWage,club.players.reduce((n,p)=>n+p.salary,0));
  assert.equal(row.players,row.contractTermsObserved+row.missingEnd);
  assert.equal(row.bookedPayable,null);assert.equal(row.remainingGuaranteedWages,null);
  assert.equal(row.planning29Weeks,row.weeklyWage*29);
 }
});
test('E2.4: a native market offer is not booked as a debt',()=>{
 const g=N.fresh(),s=O.snapshot(g),before=O.contractEvidence(s);
 g.ctx.__e24={id:'unaccepted-test',playerId:s.clubs[0].players[0].id,buyer:1,fee:180000,expires:100};
 g.run('S.economy.offers.push(__e24)');delete g.ctx.__e24;
 const x=O.contractEvidence(O.snapshot(g));
 assert.equal(x.offersPending,before.offersPending+1);
 assert.ok(x.clubs.every(c=>c.bookedPayable===null));
});
test('E2.4: real native accepted interclub sale conserves cash and ownership',()=>{
 const result=O.validateTransferFixture(N.fresh(0,827381));
 assert.equal(result.cashConserved,true);assert.equal(result.ownershipUnique,true);
});
test('E2.4: save export is unchanged by read-only obligations audit',()=>{
 const g=N.fresh(),a=N.data(g,'createSaveDocument()');
 const s=O.snapshot(g);O.contractEvidence(s);O.rosterChanges(s,s);
 const b=N.data(g,'createSaveDocument()');
 assert.deepEqual(a.state,b.state);assert.equal(a.checksum,b.checksum);
});
test('E2.4: budget illustration is not promoted into enforceable liability',()=>{
 const g=N.fresh(),x=O.contractEvidence(O.snapshot(g));
 assert.ok(x.clubs.some(c=>c.planning29Weeks>0));
 assert.ok(x.clubs.every(c=>c.contractDebt===null));
 assert.equal(x.classification.forecast.includes('illustration'),true);
});
