'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),E=require('./economy-v2-components.cjs'),N=require('./career-resilience/native.cjs');
test('E2.2: classify explicit manager labels conservatively',()=>{
 assert.equal(E.categorizeTitle('Billetterie',500),'revenue');
 assert.equal(E.categorizeTitle('Salaires',-500),'expense');
 assert.equal(E.categorizeTitle('Mystère',-500),'unclassified-cost');
});
test('E2.2: native first round reconciles each cash mutation',()=>{
 const g=N.fresh(0,827381);
 const x=E.auditedAction(g,()=>N.round(g,N.newStats()),'round');
 assert.equal(x.rows.reduce((s,r)=>s+r.delta,0),x.delta);
 assert.equal(x.trace.anomalies,0);
 assert.equal(x.trace.unknownSource,0);
});
test('E2.2: native rollover reconciles all components without inventing payments',()=>{
 const g=N.fresh(0,99173);
 while(g.run('S.phase')!=='ended')g.run('finishRound()');
 const x=E.auditedAction(g,()=>g.run('advanceSeason()'),'rollover');
 assert.equal(x.rows.reduce((s,r)=>s+r.delta,0),x.delta);
 assert.ok(x.rows.some(r=>r.site.includes('worldNewSeason')));
});
