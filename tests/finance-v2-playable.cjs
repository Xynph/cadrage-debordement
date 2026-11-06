'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const ui=require('../dist/finance-v2.js');
function career(){
 return {club:0,season:2,phase:'league',live:null,trained:false,
  integratedManagementVersion:1,worldVersion:1,
  clubs:[{id:0,cash:3000000,players:[{salary:15000},{salary:10000}]}],
  careerManagement:{version:1,academyInvestment:4000,academySpent:8000,academyWeeks:2},
  worldManagement:{version:1,clubInfo:[{facilities:2}],upgrades:[]},
  ledger:[{title:'Partenaires',amount:160000},{title:'Salaires',amount:-25000}]};
}
test('real career: native cash wages retained ledger and quote',()=>{
 const s=career(),before=JSON.stringify(s),x=ui.snapshot(s);
 assert.equal(x.cash,3000000);assert.equal(x.wages,25000);
 assert.equal(x.income,160000);assert.equal(x.expenses,25000);
 assert.equal(x.facilityCost,750000);assert.equal(x.facilityAllowed,true);
 assert.equal(x.academyAllowed,true);
 assert.equal(JSON.stringify(s),before,'render must not mutate any save state');
});
test('academy modes and facility button call the existing native handlers',()=>{
 const html=ui.html(career());
 for(const n of [0,4000,12000])assert.ok(html.includes('careerSetAcademyInvestment('+n+')'));
 assert.match(html,/onclick="worldUpgradeFacility\(\)"/);
 assert.match(html,/Trésorerie actuelle/);
 assert.match(html,/Consulter les contrats/);
});
test('old save: optional integrations require explicit activation',()=>{
 const s=career();delete s.careerManagement;delete s.worldManagement;delete s.integratedManagementVersion;delete s.worldVersion;
 const before=JSON.stringify(s),h=ui.html(s);
 assert.match(h,/careerEnable\(\)/);assert.match(h,/worldEnable\(\)/);
 assert.equal(JSON.stringify(s),before);
});
test('no purchase if cash insufficient or construction already performed',()=>{
 const s=career();s.clubs[0].cash=1000000;
 assert.equal(ui.snapshot(s).facilityAllowed,false);
 s.clubs[0].cash=4000000;s.worldManagement.upgrades.push({season:2,id:0,level:3});
 assert.equal(ui.snapshot(s).facilityAllowed,false);
});
test('match, end season and completed training disable spending choices',()=>{
 for(const patch of [{live:{}},{phase:'ended'},{trained:true}]){
  const s=Object.assign(career(),patch),x=ui.snapshot(s);
  assert.equal(x.facilityAllowed,false);assert.equal(x.academyAllowed,false);
  assert.match(ui.html(s),/disabled/);
 }
});
test('journal titles escaped, no fictitious debt, no write during render',()=>{
 const s=career();s.ledger=[{title:'<script>alert(1)</script>',amount:-7}];
 const h=ui.html(s);
 assert.ok(!h.includes('<script>'));assert.ok(h.includes('&lt;script&gt;'));
 assert.match(h,/indisponibles sans preuve native/);
});
test('production navigation loads dashboard before native finance panels',()=>{
 const game=fs.readFileSync(path.join(__dirname,'../dist/game.js'),'utf8');
 const index=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
 assert.match(game,/function finance\(\)\{return \(typeof CDFinanceV2/);
 assert.ok(index.indexOf('finance-v2.js')<index.indexOf('game.js'));
 assert.ok(index.includes('src="finance-v2.js"'));
});

test('native match engine: facility purchase and academy training survive save import',()=>{
 const vm=require('node:vm');
 const {context}=require('./harness.cjs');
 const g=context(),run=g.run;
 vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist/finance-v2.js'),'utf8'),g.ctx);
 run('start(0)');
 assert.match(run('finance()'),/Finances V2/);
 const before=run('club().cash');
 const quote=run('worldFacilityQuote(S.club).cost');
 assert.equal(run('worldUpgradeFacility()'),true);
 assert.equal(run('club().cash'),before-quote);
 assert.equal(run('worldUpgradeFacility()'),false);
 assert.equal(run('worldClub(S.club).facilities'),3);
 assert.equal(run('careerSetAcademyInvestment(4000)'),true);
 const selectedCash=run('club().cash');
 assert.equal(selectedCash,before-quote,'selection alone must not charge');
 run('trainWeek()');
 assert.equal(run('club().cash'),selectedCash-4000);
 assert.equal(run('S.careerManagement.academyWeeks'),1);
 assert.equal(run('careerAcademyTraining()'),false,'same training period must not double-charge');
 const saved=JSON.parse(run('JSON.stringify(createSaveDocument())'));
 assert.equal(saved.state.worldManagement.clubInfo[0].facilities,3);
 assert.equal(saved.state.careerManagement.academyInvestment,4000);
 const reloaded=context();
 reloaded.ctx.__payload=JSON.stringify(saved);
 assert.equal(reloaded.run('pendingSave=parseSaveDocument(__payload);confirmSaveImport()'),true);
 assert.equal(reloaded.run('club().cash'),selectedCash-4000);
 assert.equal(reloaded.run('worldClub(S.club).facilities'),3);
 assert.equal(reloaded.run('S.careerManagement.academyWeeks'),1);
});
