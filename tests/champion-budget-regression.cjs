'use strict';
// Native regression: final fixtures use the real match simulator; no user save.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {context} = require('./harness.cjs');
const passed = [], failed = [];
function test(name, fn) {
  try { fn(); passed.push(name); console.log('PASS ' + name); }
  catch (e) { failed.push({name, error:e.message}); console.error('FAIL ' + name + ': ' + e.message); }
}
const data = (g, expr='S') => JSON.parse(g.run('JSON.stringify(' + expr + ')'));
function fresh() { const g=context(); g.run('start(0)'); return g; }
function valid(g) {
  const doc=data(g,'createSaveDocument()');
  g.ctx.__document=JSON.stringify(doc);
  assert.equal(g.run('parseSaveDocument(__document).checksum'),doc.checksum);
  delete g.ctx.__document; return doc;
}
function finalFixture({legacy=false,loser=false}={}) {
  const g=context();g.run('start('+(loser?13:0)+')');
  if(legacy)g.run('delete S.worldVersion;delete S.worldManagement;delete S.integratedManagementVersion;delete S.careerManagement');
  g.run('S.phase="final";S.round=26;S.playoff={seeds:[0,1,2,3,4,5],pairs:[[0,13]],log:[]};for(let i=0;i<100;i++)ledgerEntry("History "+i,0)');
  valid(g);return g;
}
function settled(g) {
  const before=g.run('club().cash');g.run('globalThis.__entriesBefore=new Set(S.ledger);finishRound()');
  const created=data(g,'S.ledger.filter(e=>!__entriesBefore.has(e))');
  delete g.ctx.__entriesBefore;
  assert.equal(g.run('S.phase'),'ended');
  assert.equal(g.run('club().cash')-before,created.reduce((n,e)=>n+e.amount,0),'Cash equals new native ledger entries');
  return created;
}
test('01 title with full ledger remains bounded and exports',()=>{
  const g=finalFixture();const entries=settled(g);
  assert.equal(g.run('S.worldManagement.champion'),0);
  assert.equal(g.run('S.ledger.length'),100);
  assert.equal(entries.filter(e=>e.title==='Prime de champion').length,1);
  assert.equal(entries.find(e=>e.title==='Prime de champion').amount,1000000);
  valid(g);
});
test('02 automatic save after title can actually be reopened',()=>{
  const g=finalFixture();settled(g);assert.equal(g.run('lastSaveError'),false);
  const stored=JSON.parse(g.store['bdt-v1']);const h=context(stored);
  assert.ok(h.run('S'));assert.deepEqual(data(h),data(g));valid(h);
});
test('03 confirmed import after title preserves every career field',()=>{
  const g=finalFixture();settled(g);const doc=valid(g),h=context();
  h.ctx.__incoming=JSON.stringify(doc);h.run('pendingSave=parseSaveDocument(__incoming)');
  assert.equal(h.run('confirmSaveImport()'),true);assert.deepEqual(data(h),doc.state);valid(h);
});
test('04 repeated final settlement never credits the champion twice',()=>{
  const g=finalFixture();settled(g);const before=data(g),bytes=g.store['bdt-v1'];
  g.run('finishRound();finishRound()');assert.deepEqual(data(g),before);assert.equal(g.store['bdt-v1'],bytes);
});
test('05 replay after reload does not settle an ended season again',()=>{
  const g=finalFixture();settled(g);const h=context(JSON.parse(g.store['bdt-v1'])),before=data(h);
  assert.ok(before);h.run('finishRound()');assert.deepEqual(data(h),before);valid(h);
});
test('06 old career without world/management retains the same prize rule',()=>{
  const g=finalFixture({legacy:true});const entries=settled(g);
  assert.equal(entries.filter(e=>e.title==='Prime de champion').length,1);
  assert.equal(g.run('S.ledger.length'),100);valid(g);
  assert.equal(g.run('worldActive()'),false);assert.equal(g.run('careerIntegrated()'),false);
});
test('07 non-champion is not credited a manager prize',()=>{
  const g=finalFixture({loser:true});const entries=settled(g);
  assert.notEqual(g.run('S.worldManagement.champion'),13);
  assert.equal(entries.filter(e=>e.title==='Prime de champion').length,0);valid(g);
});
test('08 storage failure preserves the previous bytes and retry pays once',()=>{
  const g=finalFixture();g.run('save()');const previous=g.store['bdt-v1'],original=g.ctx.localStorage.setItem;
  g.ctx.localStorage.setItem=()=>{throw Error('Test storage failure')};settled(g);
  assert.equal(g.run('lastSaveError'),true);assert.equal(g.store['bdt-v1'],previous);valid(g);
  const after=g.run('club().cash');g.ctx.localStorage.setItem=original;g.run('finishRound();save()');
  assert.equal(g.run('lastSaveError'),false);assert.equal(g.run('club().cash'),after);
  const h=context(JSON.parse(g.store['bdt-v1']));assert.ok(h.run('S'));valid(h);
});
test('09 next season after a title is valid without another champion payment',()=>{
  const g=finalFixture();settled(g);g.run('advanceSeason()');
  assert.equal(g.run('S.season'),2);assert.equal(g.run('S.phase'),'league');
  assert.equal(g.run('S.ledger.filter(e=>e.title==="Prime de champion").length'),1);valid(g);
});
test('10 validator still rejects 101 entries, no enlarged limit',()=>{
  const g=fresh();g.run('for(let i=0;i<100;i++)ledgerEntry("Synthetic history",0);S.ledger.unshift({title:"Overflow",amount:0})');
  assert.throws(()=>g.run('createSaveDocument()'));assert.equal(g.run('S.ledger.length'),101);
});
for(const level of [2,3,7,10])test('forecast matches native upkeep at level '+level,()=>{
  const g=fresh();g.run('worldClub(S.club).facilities='+level);
  const before=data(g),model=data(g,'careerBudgetModel()'),upkeep=g.run('worldUpkeep('+level+')');
  assert.equal(model.weeklyOtherCosts,upkeep);assert.deepEqual(data(g),before,'Read-only forecast');
  const cash=g.run('club().cash');g.run('financeWeek(null,false);worldWeeklyEconomy([])');
  assert.equal(g.run('club().cash')-cash,model.weeklyIncome-model.weeklyWages-model.weeklyOtherCosts);valid(g);
});
test('15 level 3 includes exactly 2900 per period and 34800 over 12 periods',()=>{
  const g=fresh();g.run('worldUpgradeFacility()');const a=data(g,'careerFinancialAnalysis()');
  assert.equal(a.base.weeks,12);assert.equal(a.base.weeklyOtherCosts,2900);
  const old=a.base.cash+(a.base.weeklyIncome-a.base.weeklyWages)*a.base.weeks;
  assert.equal(old-a.projection.finalBalance,34800);
});
test('16 investment immediately updates the forecast, without billing it twice',()=>{
  const g=fresh(),before=g.run('club().cash'),price=g.run('worldFacilityQuote(S.club).cost');
  assert.equal(g.run('worldUpgradeFacility()'),true);
  const snapshot=data(g);g.run('careerBudgetModel();careerFinancialAnalysis();careerFinancePanel()');
  assert.deepEqual(data(g),snapshot);assert.equal(g.run('club().cash'),before-price);
  assert.equal(g.run('worldUpgradeFacility()'),false);assert.equal(g.run('club().cash'),before-price);valid(g);
});
for(const sponsor of ['prudent','performance','avance'])test('sponsor '+sponsor+' plus formation and maintenance counted once',()=>{
  const g=fresh();g.run('careerSponsorPick('+JSON.stringify(sponsor)+');worldUpgradeFacility();careerSetAcademyInvestment(4000)');
  const m=data(g,'careerBudgetModel()'),cash=g.run('club().cash');
  assert.equal(m.weeklyOtherCosts,6900);
  g.run('trainWeek();financeWeek(null,false);worldWeeklyEconomy([])');
  assert.equal(g.run('club().cash')-cash,m.weeklyIncome-m.weeklyWages-m.weeklyOtherCosts);valid(g);
});
test('20 pre-world saves keep zero additional facility charge',()=>{
  const g=fresh();g.run('delete S.worldVersion;delete S.worldManagement');
  assert.equal(g.run('careerBudgetModel().weeklyOtherCosts'),0);valid(g);
});
test('21 projected alternatives keep the same maintenance baseline',()=>{
  const g=fresh();g.run('worldUpgradeFacility();careerSetAcademyInvestment(4000)');
  const a=data(g,'careerFinancialAnalysis()');assert.equal(a.base.weeklyOtherCosts,6900);
  assert.equal(a.comparison.scenarios[0].delta,-10000*a.base.weeks);
  assert.equal(a.comparison.scenarios[1].delta,-4000*a.base.weeks);
});
test('22 import preserves facility level and the derived forecast',()=>{
  const g=fresh();g.run('worldUpgradeFacility();careerSetAcademyInvestment(4000)');const doc=valid(g),h=context();
  h.ctx.__incoming=JSON.stringify(doc);h.run('pendingSave=parseSaveDocument(__incoming);confirmSaveImport()');
  assert.deepEqual(data(h,'careerBudgetModel()'),data(g,'careerBudgetModel()'));valid(h);
});
const report={passed:failed.length===0,groups:passed.length+failed.length,passedGroups:passed,failedGroups:failed,
  scope:'Native functions, real deterministic final simulator, explicit boundary fixtures; no user saves',
  limitations:['Not a complete season campaign','No Windows native test','Existing invalid saves are not silently migrated']};
if(process.env.CD_CHAMPION_BUDGET_REPORT)fs.writeFileSync(process.env.CD_CHAMPION_BUDGET_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('CHAMPION BUDGET REGRESSION '+JSON.stringify({passed:report.passed,groups:report.groups,failures:failed.length}));
if(failed.length)process.exitCode=1;
