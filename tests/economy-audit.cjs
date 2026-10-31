'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const A=require('./economy-audit/native.cjs'),N=A.N;
const checks=[],observations=[];
function test(name,fn){fn();checks.push(name);console.log('PASS '+name);}
const fresh=()=>N.fresh(0,827381);
const cash=g=>g.run('club().cash');
const save=g=>{const d=N.data(g,'createSaveDocument()');g.ctx.__verify=JSON.stringify(d);assert.equal(g.run('parseSaveDocument(__verify).checksum'),d.checksum);return d;};
function book(g){return N.data(g,'({cash:club().cash,ledger:S.ledger,roster:club().players.map(p=>p.id)})');}
function reportFor(g){return {checks:N.newStats(),clubTotals:A.snapshot(g).clubs.map(c=>({id:c.id,flows:{},minCash:c.cash,negativeCheckpoints:0,debtInterest:0})),maxUnexplainedResidual:0,rounds:0,matches:0,neutralVenueTicketAllocations:[],transitions:[]};}

test('01 observer and real round preserve complete state and RNG versus witness',()=>{
 const g=fresh(),control=N.fork(g),r=reportFor(g);A.round(g,r);control.run('finishRound()');
 assert.deepEqual(N.data(g),N.data(control));assert.deepEqual(N.rng(g),N.rng(control));assert.equal(r.matches,7);assert.equal(r.maxUnexplainedResidual,0);
});
test('02 all 14 clubs reconciled for an actual round',()=>{
 const g=fresh(),r=reportFor(g);A.round(g,r);assert.equal(r.checks.byCheck['cash-reconciliation-round'],14);save(g);
});
test('03 investment refused one euro below full liquidity requirement',()=>{
 const g=fresh();const threshold=g.run('worldFacilityQuote(S.club).total+500000');g.run('club().cash='+(threshold-1));
 const b=N.data(g);assert.equal(g.run('worldFacilityQuote(S.club).affordable'),false);assert.equal(g.run('worldUpgradeFacility()'),false);assert.deepEqual(N.data(g),b);
});
test('04 exact investment threshold debits capex, not the forecast reserve',()=>{
 const g=fresh(),q=N.data(g,'worldFacilityQuote(S.club)');g.run('club().cash='+(q.total+500000));
 assert.equal(g.run('worldUpgradeFacility()'),true);A.close(cash(g),q.total+500000-q.cost,'Capex only');assert.equal(g.run('worldClub(S.club).facilities'),3);
 const after=book(g);assert.equal(g.run('worldUpgradeFacility()'),false);assert.deepEqual(book(g),after);save(g);
});
test('05 investment cannot be billed twice after native export/import',()=>{
 const g=fresh();g.run('worldUpgradeFacility()');const restored=N.fork(g),b=book(restored);
 assert.equal(restored.run('worldUpgradeFacility()'),false);assert.deepEqual(book(restored),b);
});
test('06 funded formation session uses the native training flow once',()=>{
 const g=fresh();g.run('careerSetAcademyInvestment(4000);club().cash=4000;trainWeek()');
 assert.equal(cash(g),0);assert.equal(g.run('S.careerManagement.academySpent'),4000);g.run('trainWeek()');assert.equal(cash(g),0);
 const h=N.fork(g);h.run('trainWeek()');assert.equal(h.run('S.careerManagement.academySpent'),4000);save(h);
});
test('07 unfunded formation causes no financial debit or false paid week',()=>{
 const g=fresh();g.run('careerSetAcademyInvestment(4000);club().cash=3999;trainWeek()');assert.equal(cash(g),3999);
 assert.equal(g.run('S.careerManagement.academySpent'),0);assert.equal(g.run('S.careerManagement.academyWeeks'),0);save(g);
});
test('08 sponsor signing paid once and persisted',()=>{
 const g=fresh(),b=cash(g);assert.equal(g.run('careerSponsorPick("avance")'),true);assert.equal(cash(g),b+120000);
 const h=N.fork(g);assert.equal(h.run('careerSponsorPick("avance")'),false);assert.equal(cash(h),b+120000);
});
test('09 sponsor payments and salaries reconciled in an actual round',()=>{
 const g=fresh();g.run('careerSponsorPick("prudent")');const r=reportFor(g);A.round(g,r);
 assert.equal(r.clubTotals[0].flows.sponsorHebdo.amount,9500);assert.equal(r.clubTotals[0].flows.partenaires.count,1);save(g);
});
test('10 recruitment at exact fee, not enough by one euro, then single signature',()=>{
 const g=fresh();g.run('var econCandidate=S.market[0];negotiateContract(econCandidate.id,"recruit",100000,1);var econKey=talkKey(econCandidate.id,"recruit")');
 const fee=g.run('S.economy.talks[econKey].fee');g.run('club().cash='+(fee-1));let b=book(g);
 assert.equal(g.run('confirmContract(econKey)'),false);assert.deepEqual(book(g),b);
 g.run('club().cash='+fee);assert.equal(g.run('confirmContract(econKey)'),true);assert.equal(cash(g),0);save(g);
 const h=N.fork(g);h.ctx.__key=g.run('econKey');b=book(h);assert.equal(h.run('confirmContract(__key)'),false);assert.deepEqual(book(h),b);
});
test('11 real sale conserves both budgets and unique player ownership',()=>{
 const g=fresh();g.run('var econSold=club().players[5];toggleListing(econSold.id);economyWeek();var econOffer=S.economy.offers.find(x=>x.playerId===econSold.id)');
 assert.ok(g.run('econOffer'));const before=g.run('S.clubs.reduce((n,c)=>n+c.cash,0)');
 assert.equal(g.run('acceptSale(econOffer.id)'),true);A.close(g.run('S.clubs.reduce((n,c)=>n+c.cash,0)'),before,'Transfer conservation');
 assert.equal(g.run('S.clubs.flatMap(c=>c.players).filter(p=>p.id===econSold.id).length'),1);const h=N.fork(g);h.ctx.__id=g.run('econOffer.id');
 assert.equal(h.run('acceptSale(__id)'),false);save(h);
});
test('12 buyer short by one euro cannot buy or move the player',()=>{
 const g=fresh();g.run('var econSold=club().players[5];toggleListing(econSold.id);economyWeek();var econOffer=S.economy.offers.find(x=>x.playerId===econSold.id);S.clubs[econOffer.buyer].cash=econOffer.fee-1');
 const b=N.data(g,'S.clubs');assert.equal(g.run('acceptSale(econOffer.id)'),false);assert.deepEqual(N.data(g,'S.clubs'),b);
});
test('13 storage failure remains visible and retry never duplicates investment',()=>{
 const g=fresh();g.run('save()');const original=g.ctx.localStorage.setItem,last=g.store['bdt-v1'],before=cash(g),price=g.run('worldFacilityQuote(S.club).cost');
 g.ctx.localStorage.setItem=()=>{throw Error('Simulated storage unavailable')};
 assert.equal(g.run('worldUpgradeFacility()'),true);assert.ok(g.run('lastSaveError'));assert.equal(g.store['bdt-v1'],last);assert.equal(cash(g),before-price);
 g.ctx.localStorage.setItem=original;assert.equal(g.run('worldUpgradeFacility()'),false);g.run('save()');assert.ok(!g.run('lastSaveError'));save(g);
 assert.equal(cash(g),before-price);assert.notEqual(g.store['bdt-v1'],last);
});
test('14 corrupted import rejected without changing current cash or saved bytes',()=>{
 const g=fresh(),b=book(g),stored=g.store['bdt-v1'];const d=save(g);d.state.clubs[0].cash+=12345;g.ctx.__bad=JSON.stringify(d);
 assert.throws(()=>g.run('parseSaveDocument(__bad)'));assert.deepEqual(book(g),b);assert.equal(g.store['bdt-v1'],stored);
});
test('15 private world weekly function guarded against a repeated period',()=>{
 const g=fresh();assert.equal(g.run('worldWeeklyEconomy([])'),true);const b=N.data(g);
 assert.equal(g.run('worldWeeklyEconomy([])'),false);assert.deepEqual(N.data(g),b);
});
test('16 fixture observation: forecast V41 omits known facilities upkeep',()=>{
 const g=fresh();g.run('worldUpgradeFacility()');const before=cash(g),model=N.data(g,'careerBudgetModel()'),upkeep=g.run('worldUpkeep(worldClub(S.club).facilities)');
 // Isolated native settlement fixture without ticket or victory; not a season result.
 g.run('financeWeek(null,false);worldWeeklyEconomy([])');
 const predicted=model.weeklyIncome-model.weeklyWages-model.weeklyOtherCosts,actual=cash(g)-before;
 A.close(predicted-actual,upkeep,'Forecast gap');assert.ok(upkeep>0);
 observations.push({id:'FORECAST-UPKEEP',status:'confirmed-gap',weeklyEuros:upkeep,horizonWeeks:model.weeks,horizonEuros:upkeep*model.weeks,scope:'V41 careerBudgetModel; tickets excluded from both sides'});
});
test('17 adverse debt conversion has a liability, not free net wealth',()=>{
 const g=fresh();g.run('S.clubs[1].cash=-500000;worldClub(1).debt=200000');
 const before=A.snapshot(g);g.run('worldNewSeason()');const after=A.snapshot(g),d=before.clubs[1];
 A.close(after.clubs[1].cash,2250000,'Cash after funding and repayment');A.close(after.clubs[1].debt,478000,'Debt with interest');
 A.close((after.clubs[1].cash-after.clubs[1].debt)-(d.cash-d.debt),2500000-28000,'Net liquidity');
});
test('18 aggregate rejects a campaign falsely marked complete',()=>{
 const {validateReport}=require('../ci/economy-audit.cjs');assert.throws(()=>validateReport({schema:1,complete:true,seasons:[],expectedYears:15,checks:{failed:[]},rounds:0,matches:0}));
});
test('19 unknown ledger labels fail closed instead of disappearing from report',()=>assert.equal(A.category('unclassified operation'),'nonClasse'));
test('20 live match blocks financial roster and infrastructure actions',()=>{
 const g=fresh();g.run('var econId=S.market[0].id;beginMatch();pauseMatch()');const b=book(g);
 assert.equal(g.run('worldUpgradeFacility()'),false);assert.equal(g.run('careerSponsorPick("prudent")'),false);assert.equal(g.run('negotiateContract(econId,"recruit",10000,1)'),false);assert.deepEqual(book(g),b);
});
const report={passed:true,suites:1,scenarioGroups:checks.length,checks,observations,scope:'Native functions on isolated fictitious careers',limits:['Confirmed-gap assertions are reproductions, not proof of economic correctness','No production coefficients changed','Private helper fixtures are identified separately from full career runs']};
if(process.env.CD_ECONOMY_TEST_REPORT)fs.writeFileSync(process.env.CD_ECONOMY_TEST_REPORT,JSON.stringify(report,null,2));
console.log('ECONOMY TRANSACTIONS PASS '+JSON.stringify(report));
