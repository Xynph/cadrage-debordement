'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const P=require('../ci/economy-v2-e30-playability.cjs');
const scenario=(overrides={})=>({openingCash:100,income:[20,20,20,20],required:[30,30,30,30],
 optional:[40,40,0,0],targetReserve:20,...overrides});
test('E3.0 scenarios: maintain costly project vs stage vs pause',()=>{
 const x=P.compare(scenario());
 const [maintain,stage,pause]=x.options;
 assert.equal(maintain.endingCash,-20);
 assert.equal(stage.endingCash,20);
 assert.equal(pause.endingCash,60);
 assert.equal(maintain.optionalPaid,80);
 assert.equal(stage.optionalPaid,40);
 assert.equal(stage.optionalDeferred,40);
 assert.equal(pause.optionalDeferred,80);
 assert.equal(x.summary.recoveryPossibleWithoutNewMoney,true);
});
test('E3.0 staging invests only from demonstrated liquid surplus',()=>{
 const x=P.simulate({openingCash:80,income:[40,50,50],required:[30,30,30],optional:[60,0,0],targetReserve:50},'stage');
 assert.equal(x.optionalPaid,60);
 assert.equal(x.optionalDeferred,0);
 assert.equal(x.endingCash,70);
 assert.ok(x.weekly.every(w=>w.closingCash>=50));
});
test('E3.0 mandatory obligations are never deferred by player tactics',()=>{
 const a={openingCash:10,income:[0,0,80],required:[30,30,30],optional:[50,0,0],targetReserve:10};
 for(const mode of ['maintain','stage','pause']){
  const x=P.simulate(a,mode);
  assert.deepEqual(x.weekly.map(w=>w.mandatoryPaid),a.required);
  assert.ok(x.requiredCoverageRiskWeeks>=2);
  assert.equal(x.generatedLoans,0);assert.equal(x.generatedIncome,0);
  assert.equal(x.createdDebt,0);assert.equal(x.addedPenalties,0);
  assert.equal(x.firstDeficitWeek,1);if(mode==='maintain')assert.equal(x.firstRecoveryWeek,null);else assert.equal(x.firstRecoveryWeek,3);
 }
 assert.equal(P.compare(a).summary.optionalChangesInsufficientForMandatoryBills,true);
});
test('E3.0 no fake recovery if mandatory spending exceeds all actual income',()=>{
 const q=P.compare({openingCash:0,income:[0,0,0],required:[100,100,100],optional:[0,0,0]});
 assert.equal(q.summary.recoveryPossibleWithoutNewMoney,false);
 assert.equal(q.summary.voluntaryChoiceAvailable,false);
 assert.equal(q.options[2].endingCash,-300);
});
test('E3.0 no wage floor or negative optional salary inference',()=>{
 const x=P.compare({openingCash:1,income:[0,50],required:[0,0],optional:[20,0]});
 assert.equal(x.options[2].endingCash,51);
 assert.equal(x.options[1].optionalPaid,20);
 assert.ok(x.options.every(s=>s.addedPenalties===0));
});
test('E3.0 forecasts cannot mutate caller input or the game',()=>{
 const a=scenario(),before=JSON.stringify(a);
 P.compare(a);assert.equal(JSON.stringify(a),before);
});
test('E3.0 refuses invented income, credit and invalid balances',()=>{
 assert.throws(()=>P.compare({...scenario(),automaticLoan:1000}),/prêt ni revenu/);
 assert.throws(()=>P.compare({...scenario(),unverifiedIncome:400}),/prêt ni revenu/);
 assert.throws(()=>P.compare({...scenario(),openingCash:Infinity}),/Trésorerie/);
 assert.throws(()=>P.compare({...scenario(),optional:[-1,0,0,0]}),/Flux négatif/);
 assert.throws(()=>P.compare({...scenario(),required:[0]}),/Calendrier/);
 assert.throws(()=>P.compare({...scenario(),targetReserve:-1}),/Réserve/);
});
test('E3.0 phase choices do not create artificial payable liabilities',()=>{
 const x=P.compare({openingCash:50,income:[10,10],required:[0,0],optional:[100,0],targetReserve:50});
 assert.equal(x.options[1].optionalDeferred,80);
 assert.equal(x.options[1].createdDebt,0);
 assert.equal(x.options[2].createdDebt,0);
 assert.equal(x.options[0].optionalPaid,100);
});
test('E3.0 optional future commitments not assumed to be legally due',()=>{
 const x=P.simulate({openingCash:0,income:[0],required:[0],optional:[100]},'pause');
 assert.equal(x.endingCash,0);
 assert.equal(x.optionalDeferred,100);
 assert.equal(x.createdDebt,0);
});
