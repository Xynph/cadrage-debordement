'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs'),D=require('./economy-v2-debt-audit.cjs');
test('E2.3: first native round preserves all 14 debts',()=>{
 const g=N.fresh(0,827381),s=N.newStats(),o=D.round(g,s);
 assert.equal(o.before.clubs.length,14);assert.equal(o.after.clubs.length,14);
 assert.equal(s.failed.length,0);
});
test('E2.3: native season rollover independently reconciles debt',()=>{
 const g=N.fresh(0,99173);while(g.run('S.phase')!=='ended')g.run('finishRound()');
 const o=D.rollover(g);assert.equal(o.debtRows.length,14);
 for(const row of o.debtRows)assert.ok(Math.abs(row.openingDebt+row.debtConverted+row.interest-row.repayment-row.closingDebt)<1e-6);
});
test('E2.3: stressed native rollover correctly converts deficit into debt',()=>{
 const g=N.fresh(0,827381);
 g.run('S.clubs[1].cash=-150000;worldClub(1).debt=500000');
 // Exercise the true native transition while explicitly marking this as an injected test fixture.
 const before=D.snapshot(g);
 g.run('worldNewSeason()');
 const after=D.snapshot(g);
 const b=before.clubs[1],a=after.clubs[1],opening=b.debt+150000;
 const paid=Math.min(250000,opening,opening*1.04,2500000);
 assert.equal(a.cash,2500000-paid);
 assert.ok(Math.abs(a.debt-(opening*1.04-paid))<1e-6);
});
test('E2.3: contracts are exposure indicators, not fabricated booked liabilities',()=>{
 const x=D.exposures(D.snapshot(N.fresh()));
 assert.equal(x.clubs.length,14);
 assert.equal(x.bookedLiabilityAvailable,false);
 assert.ok(x.clubs.every(c=>c.bookedPayable===null&&c.estimatedFutureCommitment===null));
});
test('E2.3: saved state and checksum retain native parity under inspection',()=>{
 const a=N.fresh(0,827381),b=N.fresh(0,827381);
 N.round(a,N.newStats());D.round(b,N.newStats());
 const x=N.data(a,'createSaveDocument()'),y=N.data(b,'createSaveDocument()');
 assert.deepEqual(x.state,y.state);assert.equal(x.checksum,y.checksum);
});
