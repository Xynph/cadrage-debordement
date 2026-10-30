'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function pure(t,expression){
 const state=t.run('JSON.stringify(S)'),stored=t.run('localStorage.getItem("bdt-v1")');
 const value=JSON.parse(t.run('JSON.stringify('+expression+')'));
 assert.equal(t.run('JSON.stringify(S)'),state,'Salary quotation must not mutate the career');
 assert.equal(t.run('localStorage.getItem("bdt-v1")'),stored,'Salary quotation must not persist anything');
 return value;
}
const fresh=context(),r=fresh.run;
r('start(0)');
assert.equal(r('S.salaryDemandVersion'),1);
assert.ok(r('contractsPanel().includes("MODÈLE V35")'));
assert.ok(r('salaryDemandPanel().includes("Expliquer les exigences salariales")'));
assert.equal(r('enableSalaryDemandModel()'),false);
r('var p=club().players.find(x=>x.contractEnd===S.season),id=p.id;var baseline=Math.max(p.salary,Math.round((roleNote(p)-43)*230/100)*100)');
const first=pure(fresh,'salaryDemandBreakdown(p,"renew")');
assert.equal(first.active,true);
assert.equal(first.base,r('baseline'));
assert.ok(first.modifier>=-.12&&first.modifier<=.12);
assert.equal(r('askingWage(p,"renew")'),first.asked);
assert.equal(r('askingWage(S.market[0],"recruit")'),r('S.market[0].salary'));
assert.equal(pure(fresh,'salaryDemandBreakdown(S.market[0],"recruit")').active,false);
assert.equal(first.factors.length,6);
assert.ok(first.factors.some(x=>x.key==='minutes'&&x.rate===0));
assert.ok(first.factors.some(x=>x.key==='progression'&&x.rate===0));
assert.equal(r('JSON.stringify(createSaveDocument().state.salaryDemandVersion)'),"1");

// Grounded variation: controlled synthetic in-game states, no invented tries
// or tackles, and no double count of V29 specialization in salary demand.
const rich=context(),h=rich.run;
h('start(0);var p=club().players.find(p=>p.contractEnd===S.season);p.age=29;p.salary=2000;p.dev.retireAge=40;p.rating=82;p.dev.potential=Math.max(90,p.rating);p.dev.seasonStart=80;p.dev.minutes=1550;p.dev.appearances=20;club().played=22;club().won=17;club().lost=5;club().cash=9000000');
const rising=pure(rich,'salaryDemandBreakdown(p,"renew")');
assert.ok(rising.modifier>=.075,'Playing, growth and club results should raise demand');
assert.ok(rising.modifier<=.12);
assert.equal(rising.factors.find(x=>x.key==='minutes').rate,.045);
assert.equal(rising.factors.find(x=>x.key==='progression').rate,.02);
assert.equal(rising.factors.find(x=>x.key==='cash').rate,.015);
assert.equal(rising.factors.find(x=>x.key==='results').rate,.015);
assert.equal(rising.asked,Math.max(h('p.salary'),Math.round(rising.base*(1+rising.modifier)/100)*100));
assert.equal(h('askingWage(p,"renew")'),rising.asked);
assert.equal(h('reservationWage(p,"renew",2)'),
 Math.ceil(rising.asked*(.86+(h('seedHash(p.id)')%8)/100)/100)*100);
// Real sport role can affect base rate, without inventing extra attribute
// points; team standing, minutes and career growth remain separate.
h('var orig=salaryDemandBreakdown(p,"renew").asked;var k=Object.keys(ROLE_WEIGHTS[p.fam])[0];ensureSpecialization(p).bonuses[k]=4;var improved=salaryDemandBreakdown(p,"renew").asked');
assert.ok(h('improved>=orig'));
const low=context(),lo=low.run;
lo('start(0);var p=club().players.find(p=>p.contractEnd===S.season);p.age=35;p.dev.retireAge=42;p.salary=2000;p.rating=75;p.dev.potential=Math.max(85,p.rating);p.dev.seasonStart=77;p.dev.minutes=200;p.dev.appearances=5;club().played=22;club().won=2;club().lost=20;club().cash=200000');
const falling=pure(low,'salaryDemandBreakdown(p,"renew")');
assert.ok(falling.modifier<0,'Older underused player, poor form and low cash reduce demand');
assert.equal(falling.factors.find(x=>x.key==='minutes').rate,-.035);
assert.equal(falling.factors.find(x=>x.key==='progression').rate,-.02);
assert.equal(falling.factors.find(x=>x.key==='age').rate,-.02);
assert.equal(falling.factors.find(x=>x.key==='cash').rate,-.025);
assert.equal(falling.factors.find(x=>x.key==='results').rate,-.015);
assert.ok(falling.asked>=lo('p.salary'));
assert.ok(falling.modifier>=-.12);
lo('p.dev.minutes=0;p.dev.appearances=0;var noEvidence=salaryDemandBreakdown(p,"renew")');
assert.equal(lo('noEvidence.factors.find(x=>x.key==="minutes").rate'),0);
assert.equal(lo('noEvidence.factors.find(x=>x.key==="progression").rate'),0);

// The same reservation threshold must govern both a V34 preview and an
// actual negotiation. Ready remains ONLY a proposal until confirmation.
const real=context(),actual=real.run;
actual('start(0);var p=club().players.find(p=>p.contractEnd===S.season),id=p.id;p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3);p.dev.minutes=800;p.dev.appearances=10;club().played=14;club().won=10;club().lost=4;var asking=askingWage(p,"renew"),min=reservationWage(p,"renew",2),cash=club().cash');
const v34=pure(real,'counterofferQuote(S,{kind:"renew",id,wage:min,years:2},2)');
assert.equal(v34.asking,actual('asking'));
assert.equal(v34.minimum,actual('min'));
assert.equal(v34.status,'ready');
assert.equal(actual('negotiateContract(id,"renew",min,2)'),true);
assert.equal(actual('S.economy.talks[talkKey(id,"renew")].status'),'ready');
assert.equal(actual('S.economy.talks[talkKey(id,"renew")].acceptedSalary'),v34.minimum);
assert.equal(actual('club().cash'),actual('cash'));
assert.equal(actual('p.contractEnd'),1);
assert.ok(actual('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));

// Old V34 saves keep exact original financial assumptions until opted-in.
const base=JSON.parse(r('JSON.stringify(S)'));delete base.salaryDemandVersion;
const historical=context(base),l=historical.run;
assert.equal(l('S.salaryDemandVersion'),undefined);
l('var p=club().players.find(p=>p.contractEnd===S.season),id=p.id;var legacy=Math.max(p.salary,Math.round((roleNote(p)-43)*230/100)*100)');
assert.equal(l('askingWage(p,"renew")'),l('legacy'));
assert.equal(pure(historical,'salaryDemandBreakdown(p,"renew")').modifier,0);
assert.ok(l('salaryDemandPanel().includes("Activer les demandes évolutives")'));
assert.ok(l('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
const oldState=l('JSON.stringify(S)'),oldStorage=l('localStorage.getItem("bdt-v1")');
pure(historical,'salaryDemandPanel()');
assert.equal(l('JSON.stringify(S)'),oldState);
assert.equal(l('localStorage.getItem("bdt-v1")'),oldStorage);
assert.equal(l('enableSalaryDemandModel()'),true);
assert.equal(l('S.salaryDemandVersion'),1);
assert.ok(l('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
assert.equal(JSON.parse(historical.store['bdt-v1']).salaryDemandVersion,1);
assert.equal(l('enableSalaryDemandModel()'),false);
l('S.salaryDemandVersion=2');
assert.throws(()=>l('validateCareer(S)'));
l('S.salaryDemandVersion=1');
l('S.salaryDemandVersion="yes"');
assert.throws(()=>l('validateCareer(S)'));
l('S.salaryDemandVersion=1');

// Explicit opt-in is blocked while a match is open or talks are recorded.
const active=context(base),a=active.run;
a('beginMatch();pauseMatch()');
assert.equal(a('enableSalaryDemandModel()'),false);
assert.equal(a('S.salaryDemandVersion'),undefined);
const live=JSON.parse(a('JSON.stringify(S)'));
const resumed=context(live),res=resumed.run;
assert.equal(res('S.salaryDemandVersion'),undefined);
assert.equal(res('S.live.minute'),live.live.minute);
assert.deepEqual(JSON.parse(res('JSON.stringify(S.live.score)')),live.live.score);
assert.equal(res('enableSalaryDemandModel()'),false);
assert.ok(res('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
const discussed=context(base),di=discussed.run;
di('var p=club().players.find(p=>p.contractEnd===S.season);negotiateContract(p.id,"renew",1000,2)');
assert.ok(di('Object.keys(S.economy.talks).length>0'));
assert.equal(di('enableSalaryDemandModel()'),false);
assert.equal(di('S.salaryDemandVersion'),undefined);

// Calibration over four actual season transitions. Synthetic sample minutes
// and progression are openly distinguished from a full played league.
// Compare actual reservation formulas, bounded drift, previous-year history,
// proper save validation, and stable rugby team eligibility.
const seasons=context(),y=seasons.run;
y('start(0)');
const sampled=[];
for(let i=0;i<4;i++){
 y('var p=club().players.find(q=>q.contractEnd===S.season)||club().players[0];var base=Math.max(p.salary,Math.round((roleNote(p)-43)*230/100)*100);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3);p.dev.minutes=800;p.dev.appearances=12;club().played=16;club().won=10;club().lost=6;club().cash=4000000');
 const model=pure(seasons,'salaryDemandBreakdown(p,"renew")');
 assert.ok(model.active&&model.modifier<=.12&&model.modifier>=-.12);
 assert.equal(model.base,y('base'));
 assert.equal(model.asked,y('askingWage(p,"renew")'));
 assert.ok(Number.isFinite(y('reservationWage(p,"renew",2)')));
 sampled.push({season:y('S.season'),base:model.base,requested:model.asked,modifier:model.modifier,
  salaryReserved:y('reservationWage(p,"renew",2)')});
 assert.ok(y('!!createSaveDocument()'));
 y('S.phase="ended";S.round=26;advanceSeason()');
 assert.equal(y('S.season'),i+2);
 assert.equal(y('sheetErrors().length'),0);
 assert.ok(y('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
}
assert.equal(sampled.length,4);
console.log(JSON.stringify({passed:true,seasons:4,sampled,checks:['V34 base preserved','bounded ±12%','minutes and performance proxy','position cover','age and club situation','no random/no save on quote','V34 real negotiation','optional old-save marker and explicit opt-in','live and talks protected','four valid interseasons']}));
