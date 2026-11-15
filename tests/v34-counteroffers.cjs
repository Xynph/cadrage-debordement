'use strict';
const assert=require('node:assert/strict');
const {planningContext:context}=require('./helpers/gestion-domaines.cjs');
const {engineContext}=require('./harness.cjs');
const storageSnapshot=t=>t.storageText?t.storageText():t.store['bdt-v1'];
const plain=x=>JSON.parse(JSON.stringify(x));
function pure(t,expr){
 const old=t.run('JSON.stringify(S)'),storage=JSON.stringify(storageSnapshot(t));
 const result=JSON.parse(t.run('JSON.stringify('+expr+')'));
 assert.ok(t.run('JSON.stringify(S)')===old,'A what-if must never mutate the career');
 assert.equal(JSON.stringify(storageSnapshot(t)),storage,'A what-if must never change a save');
 return result;
}
(()=>{
const one=context(),r=one.run;
r('var p=club().players.find(p=>p.contractEnd===S.season);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3);var id=p.id;var minimum=reservationWage(p,"renew",2);var fee=contractFee(p,"renew"),initialCash=club().cash');
assert.ok(r('minimum>1100'));
const atThreshold=pure(one,'counterofferQuote(S,{kind:"renew",id,wage:minimum,years:2},3)');
assert.equal(atThreshold.valid,true);
assert.equal(atThreshold.engineStatus,'ready');
assert.equal(atThreshold.status,'ready');
assert.equal(atThreshold.passes,true);
assert.equal(atThreshold.acceptedSalary,r('minimum'));
assert.equal(atThreshold.attempts,0);
assert.equal(atThreshold.nextAttempt,1);
assert.equal(atThreshold.fee,r('fee'));
assert.equal(atThreshold.end,2);
assert.equal(atThreshold.finance.delta,-atThreshold.fee-
 ((atThreshold.acceptedSalary-r('p.salary'))*r('wageForecastWeeks()')+atThreshold.acceptedSalary*r('wageForecastWeeks()')));
assert.equal(atThreshold.finance.central,r('club().cash')-atThreshold.fee+
 atThreshold.finance.annual.reduce((sum,y)=>sum+y.partners-y.payroll+
  y.homes*375000+y.matchDays*40000,0)+5000000);
assert.equal(atThreshold.succession.covered.length,3);
assert.ok(atThreshold.succession.covered.every(n=>n<=15));
assert.ok(atThreshold.v33Priority>=0&&atThreshold.v33Priority<=100);
assert.ok(atThreshold.needs>=0&&atThreshold.needs<=100);
const below=pure(one,'counterofferQuote(S,{kind:"renew",id,wage:minimum-100,years:2},3)');
assert.equal(below.valid,true);
assert.equal(below.status,'counter');
assert.equal(below.passes,false);
assert.equal(below.acceptedSalary,r('minimum'));
assert.equal(below.finance.central,atThreshold.finance.central);
const high=pure(one,'counterofferQuote(S,{kind:"renew",id,wage:minimum+100,years:2},3)');
assert.equal(high.status,'ready');
assert.equal(high.acceptedSalary,atThreshold.acceptedSalary+100);
assert.equal(high.finance.delta-atThreshold.finance.delta,-r('wageForecastWeeks()*2')*100);
assert.equal(r('club().cash'),r('initialCash'));
assert.equal(r('S.economy.transfers.length'),0);
assert.ok(r('counterofferPanel().includes("SIMULATION V34")'));
assert.ok(r('contractsPanel().includes("Comparer les contre-offres")'));
const variants=pure(one,'counterofferAlternatives(S,"renew",id,minimum,2,3)');
assert.equal(variants.length,6);
assert.ok(variants.some(v=>v.result.valid&&v.result.status==='counter'));
assert.ok(variants.some(v=>v.result.valid&&v.result.status==='ready'));
assert.ok(variants.some(v=>v.years===1));
assert.ok(variants.some(v=>v.years===3));
assert.equal(r('setCounterofferChoice("years",4)'),false);
assert.equal(r('setCounterofferChoice("horizon",0)'),false);
assert.equal(r('setCounterofferChoice("wage",999)'),false);
assert.equal(r('setCounterofferChoice("wage",100001)'),false);
assert.equal(r('setCounterofferChoice("kind","sale")'),false);
assert.equal(r('setCounterofferChoice("id","not-real")'),false);
assert.equal(r('setCounterofferChoice("kind","recruit")'),true);
assert.equal(r('counterofferChoice.kind'),'recruit');
assert.equal(r('setCounterofferChoice("kind","renew")'),true);
assert.equal(r('setCounterofferChoice("wage",5000)'),true);
assert.equal(r('counterofferChoice.wage'),5000);

// Actual negotiateContract must yield the same deterministic reply. It is
// intentionally executed only in SEPARATE contexts from what-if simulations.

// Unsupported terms, monetary bounds, a near retirement and cash constraints.
for(const expr of [
 'counterofferQuote(S,{kind:"renew",id,wage:999,years:2})',
 'counterofferQuote(S,{kind:"renew",id,wage:100001,years:2})',
 'counterofferQuote(S,{kind:"renew",id,wage:minimum,years:0})',
 'counterofferQuote(S,{kind:"renew",id,wage:minimum,years:4})',
 'counterofferQuote(S,{kind:"renew",id:"bogus",wage:5000,years:2})',
 'counterofferQuote(S,{kind:"sale",id,wage:5000,years:2})'
])assert.equal(pure(one,expr).valid,false);

one.close();
})();
(()=>{
const exact=engineContext(),ex=exact.run;exact.start(0);
ex('var p=club().players.find(p=>p.contractEnd===S.season);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3),id=p.id,min=reservationWage(p,"renew",2),cash=club().cash;negotiateContract(id,"renew",min,2);var talk=S.economy.talks[talkKey(id,"renew")]');
assert.equal(ex('talk.status'),'ready');
assert.equal(ex('talk.acceptedSalary'),ex('counterofferQuote(S,{kind:"renew",id,wage:min,years:2},3).acceptedSalary'),'même seuil du devis World et de la négociation World');
assert.equal(ex('talk.fee'),ex('contractFee(p,"renew")'));
assert.equal(ex('club().cash'),ex('cash'));
assert.equal(ex('p.contractEnd'),1,'An agreement of principle does not sign a deal');

exact.close();
})();
(()=>{
const lowActual=engineContext(),la=lowActual.run;lowActual.start(0);
la('var p=club().players.find(p=>p.contractEnd===S.season);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3),id=p.id,min=reservationWage(p,"renew",2);negotiateContract(id,"renew",min-100,2);var talk=S.economy.talks[talkKey(id,"renew")]');
assert.equal(la('talk.status'),'counter');
assert.equal(la('talk.acceptedSalary'),la('reservationWage(p,"renew",2)'),'le contre-projet World et son seuil réel concordent');
assert.equal(la('talk.attempts'),1);
const second=pure(lowActual,'counterofferQuote(S,{kind:"renew",id,wage:min-100,years:2},2)');
assert.equal(second.attempts,1);
assert.equal(second.status,'counter');
la('negotiateContract(id,"renew",min-100,2)');
const third=pure(lowActual,'counterofferQuote(S,{kind:"renew",id,wage:min-100,years:2},2)');
assert.equal(third.status,'withdrawn');
assert.equal(third.nextAttempt,3);
assert.equal(third.executable,false);
la('negotiateContract(id,"renew",min-100,2)');
assert.equal(la('S.economy.talks[talkKey(id,"renew")].status'),'withdrawn');
assert.equal(pure(lowActual,'counterofferQuote(S,{kind:"renew",id,wage:min,years:2},2)').status,'blocked');


lowActual.close();
})();
(()=>{
const retire=context(),rt=retire.run;
rt('var p=club().players.find(p=>p.contractEnd===S.season);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3),id=p.id;p.dev.retireAge=p.age+1');
assert.equal(pure(retire,'counterofferQuote(S,{kind:"renew",id,wage:5000,years:2},3)').valid,false);

retire.close();
})();
(()=>{
const lowCash=context(),lc=lowCash.run;
lc('var p=club().players.find(p=>p.contractEnd===S.season);p.dev.retireAge=Math.max(p.dev.retireAge,p.age+3),id=p.id,min=reservationWage(p,"renew",2);club().cash=0');
const noMoney=pure(lowCash,'counterofferQuote(S,{kind:"renew",id,wage:min,years:2},3)');
assert.equal(noMoney.status,'ready');
assert.equal(noMoney.executable,false);
assert.ok(noMoney.explanation.some(x=>x.toLowerCase().includes('trésorerie')));
assert.equal(lc('club().cash'),0);

// Recruiting: no hidden skill/rating/potential is used to project a player.

lowCash.close();
})();
(()=>{
const market=context(),m=market.run;
m('var p=S.market.find(p=>p.age<28),id=p.id,min=reservationWage(p,"recruit",2)');
const newcomer=pure(market,'counterofferQuote(S,{kind:"recruit",id,wage:min,years:2},3)');
assert.ok(newcomer.valid&&newcomer.status==='ready');
assert.equal(newcomer.observed,false);
assert.equal(newcomer.fee,m('p.price'));
assert.equal(newcomer.finance.delta,-newcomer.fee-newcomer.acceptedSalary*m('wageForecastWeeks()')*2);
assert.equal(m('club().players.some(q=>q.id===id)'),false);
m('p.rating=99;p.dev.potential=99;for(const k of Object.keys(p.skills))p.skills[k]=99');
const unseen=pure(market,'counterofferQuote(S,{kind:"recruit",id,wage:min,years:2},3)');
assert.deepEqual(newcomer,unseen,'Scouting must not reveal non-observed skills or potential');

// Historical V33 live save stays unchanged; live negotiation is blocked.

market.close();
})();
(()=>{
const old=engineContext(),o=old.run;
old.start(0);old.deferSaves();old.toMatch();o('beginMatch();pauseMatch()');
const saved=JSON.parse(o('JSON.stringify(S)'));
const restored=engineContext(saved),z=restored.run;
z('var p=club().players.find(p=>p.contractEnd===S.season),id=p.id,min=reservationWage(p,"renew",2)');
const blocked=pure(restored,'counterofferQuote(S,{kind:"renew",id,wage:min,years:2},3)');
assert.equal(blocked.valid,true);
assert.equal(blocked.status,'blocked');
assert.equal(blocked.executable,false);
assert.equal(z('S.live.minute'),saved.live.minute);
assert.deepEqual(JSON.parse(z('JSON.stringify(S.live.score)')),saved.live.score);
assert.ok(z('!!createSaveDocument()'));
const exp=z('JSON.stringify(createSaveDocument())');
assert.equal(z('parseSaveDocument('+JSON.stringify(exp)+').state.live.minute'),saved.live.minute);

// Four historical planning input years: quotes are reproducible and do not affect the
// input contracts and 23-player sheet; JSON is validated as component data.

old.close();restored.close();
})();
(()=>{
const years=context(),y=years.run;years.run('void 0');
const results=[];
for(let i=0;i<4;i++){
 y('var p=counterofferCandidates(S,"renew")[0],id=p.id,terms=renewalEligibleYears(S,p,2),min=reservationWage(p,"renew",terms.years)');
 const q=pure(years,'counterofferQuote(S,{kind:"renew",id,wage:min,years:terms.years},3)');
 assert.ok(q.valid&&q.finance.annual.length===3);
 assert.ok(Number.isFinite(q.finance.low)&&q.finance.low<=q.finance.central&&q.finance.central<=q.finance.high);
 assert.equal(q.minimum,y('min'));
 results.push({season:y('S.season'),status:q.status,minimum:q.minimum,fee:q.fee,
  projectedCash:q.finance.central,covered:q.succession.covered});
 y('componentPlanningYear()');
 assert.equal(y('S.season'),i+2);
 assert.equal(y('sheetErrors().length'),0);
 assert.ok(y('!!componentParse(JSON.stringify(componentDocument()))'));
}
console.log(JSON.stringify({passed:true,seasons:4,scope:'historical component inputs; native World integration checked separately',results,checks:['exact engine reply','third rejection','ready is not signed','quote and counteroffer costs','V31 financial projection','V32 succession','V33 priorities','V30 incomplete scouting','unchanged storage','paused legacy match','four historical planning input years']}));

years.close();
})();
