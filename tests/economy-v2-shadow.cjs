'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),Shadow=require('../dist/economy-v2-shadow.js');
const base=()=>({season:1,round:0,phase:'league',manager:0,clubs:[{id:0,cash:100},{id:1,cash:100}]});
test('E2: read-only observation explains manager entries without mutating snapshots',()=>{
 const a=base(),b=structuredClone(a);b.clubs[0].cash=130;b.clubs[1].cash=170;
 const original=JSON.stringify([a,b]);
 const x=Shadow.observe(a,b,[{title:'Billetterie',amount:50},{title:'Staff',amount:-20}],'round-1');
 assert.equal(x.managerReconciled,true);assert.equal(x.rows[0].unexplained,0);assert.equal(x.rows[1].unexplained,70);
 assert.equal(JSON.stringify([a,b]),original);
});
test('E2: never manufactures receipts to hide a mismatch',()=>{
 const a=base(),b=structuredClone(a);b.clubs[0].cash=110;
 const o=Shadow.observe(a,b,[],'missing-ledger');
 assert.equal(o.managerReconciled,false);
 assert.equal(Shadow.summarize([o]).unexplainedSteps,1);
});
test('E2: rejects duplicate club ids and invalid ledger values',()=>{
 const a=base();a.clubs[1].id=0;
 assert.throws(()=>Shadow.capture(a),/Invalid club snapshot/);
 assert.throws(()=>Shadow.observe(base(),base(),[{title:'x',amount:Infinity}]),/Invalid ledger entry/);
});
test('E2: season boundary stays explicitly unclassified without source events',()=>{
 const a=base(),b=structuredClone(a);b.season=2;b.round=0;b.clubs[0].cash+=100;
 const o=Shadow.observe(a,b,[],'season-rollover');
 assert.equal(o.managerReconciled,false);assert.equal(o.seasonAfter,2);
});
