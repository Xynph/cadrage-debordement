'use strict';
// E3.4 R&D only. No game imports or gameplay mutations.
const assert=require('node:assert/strict');
const E33=require('./economy-v2-e33-investments.cjs');
function build(evidence){
 const e=E33.validate(evidence);
 const f=e.facility,a=e.academy;
 const facility=f?{
  type:'facility', currentLevel:f.level, quoteImmediate:f.quote?.immediateCost??null,
  nextLevel:f.quote?.nextLevel??null,
  canExecuteNow:!!(f.quote&&f.quote.affordableNow&&!f.alreadyUpgraded&&e.phase==='league'),
  blockReason:!f.quote?'no-quote':f.alreadyUpgraded?'already-upgraded-this-season':e.phase!=='league'?'outside-league':!f.quote.affordableNow?'native-affordability-refused':null,
  // E3.3 quote is instantaneous, not a payable or a future commitment.
  historicalPaidEvents:f.paidEvents.map(x=>({...x})),
  sportingRule:f.knownEffectRule
 }:null;
 const academy=a?{
  type:'academy',selection:a.selectedWeekly,allowedChoices:[...a.allowedChoices],
  seasonSpent:a.spentThisSeason,paidWeeks:a.paidWeeksThisSeason,
  actionAvailability:'not-evaluated-from-snapshot',
  // A weekly choice is only a conditional intention. No cash is charged on selection.
  conditionalNextSessionOptions:a.allowedChoices.map(value=>({
   choice:value, cashSufficiencyAtSnapshot:e.cash>=value,
   costIfPaid:value, scheduledDebt:null, guaranteedTrainingOutcome:null
  })),sportingRule:a.knownEffectRule
 }:null;
 const out={stage:'E3.4',source:'E3.3-native-snapshot',clubId:e.clubId,
  season:e.season,round:e.round,cashAtSnapshot:e.cash,facility,academy,
  comparison:{keepStatusQuo:{immediateExtraDebit:0,guaranteedSportOutcome:null},
   facilityExecuted:false,academyTrainingExecuted:false},
  unknown:{futureExpenseSchedule:null,dueLiability:null,futureRevenue:null,
   futureSportResult:null,facilityEffectMeasured:null,academyEffectMeasured:null},
  caveat:'Native snapshot only; never compare these alternatives as predicted performance.',
  readOnly:true,gameplayChanged:false};
 validate(out);return out;
}
function validate(x){
 assert.equal(x.stage,'E3.4');assert.equal(x.source,'E3.3-native-snapshot');
 assert.equal(x.readOnly,true);assert.equal(x.gameplayChanged,false);
 assert.ok(Number.isFinite(x.cashAtSnapshot));
 for(const v of Object.values(x.unknown))assert.equal(v,null);
 assert.equal(x.comparison.facilityExecuted,false);assert.equal(x.comparison.academyTrainingExecuted,false);
 assert.equal(x.comparison.keepStatusQuo.immediateExtraDebit,0);
 if(x.facility){
  assert.equal(typeof x.facility.canExecuteNow,'boolean');
  if(x.facility.canExecuteNow){assert.equal(x.facility.blockReason,null);assert(Number.isSafeInteger(x.facility.quoteImmediate));}
  assert(Array.isArray(x.facility.historicalPaidEvents));
 }
 if(x.academy){
  assert.deepEqual(x.academy.allowedChoices,[0,4000,12000]);
  for(const c of x.academy.conditionalNextSessionOptions){
   assert(x.academy.allowedChoices.includes(c.choice));
   assert.equal(c.costIfPaid,c.choice);
   assert.equal(c.scheduledDebt,null);assert.equal(c.guaranteedTrainingOutcome,null);
  }
 }
 return x;
}
module.exports={build,validate};
