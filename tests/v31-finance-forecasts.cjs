'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const clean=obj=>JSON.parse(JSON.stringify(obj));
const equal=(a,b)=>assert.deepEqual(clean(a),clean(b));
const run=t=>t.run;

// Simulations de trésorerie : la fonction est strictement pure, même en match en cours.
const fresh=context(),r=run(fresh);
r('start(0);var before=JSON.stringify(S),beforeStorage=JSON.stringify(localStorage.getItem("bdt-v1")),rngBefore=Math.random()');
r('var baseline=forecastFinancialScenario(S,{kind:"baseline"},3),again=forecastFinancialScenario(S,{kind:"baseline"},3),html=finance()');
equal(r('baseline'),r('again'));
assert.ok(r('html.includes("Prévoir sans engager le club")'));
assert.ok(r('html.includes("Hypothèses, limites et calendrier")'));
assert.equal(r('JSON.stringify(S)'),r('before'));
assert.equal(r('JSON.stringify(localStorage.getItem("bdt-v1"))'),r('beforeStorage'));
assert.equal(r('baseline.points.length'),4);
assert.equal(r('baseline.annual[0].payments'),29);
assert.equal(r('baseline.annual[0].partners'),29*160000);
assert.equal(r('baseline.annual[0].homes'),13);
assert.equal(r('baseline.annual[0].matchDays'),26);
assert.equal(r('baseline.annual[0].payroll'),r('totalWages()*29'));
assert.equal(r('baseline.points[0].central'),r('club().cash'));
assert.equal(r('baseline.annual[0].central-baseline.annual[0].low'),r('13*75000+26*40000'));
assert.equal(r('baseline.annual[0].high-baseline.annual[0].central'),r('13*75000+26*40000'));
r('beginMatch();pauseMatch();var liveBefore=JSON.stringify(S.live),savesBefore=JSON.stringify(localStorage.getItem("bdt-v1"));financialForecastPanel();forecastFinancialScenario(S,{kind:"baseline"},3)');
assert.equal(r('JSON.stringify(S.live)'),r('liveBefore'));
assert.equal(r('JSON.stringify(localStorage.getItem("bdt-v1"))'),r('savesBefore'));
assert.equal(r('setForecastChoice("unknown","recruit")'),false);
assert.equal(r('setForecastChoice("years",9)'),false);
assert.equal(r('setForecastChoice("horizon",-1)'),false);
assert.equal(r('setForecastChoice("horizon",2)'),true);
assert.equal(r('S.live.minute'),r('JSON.parse(liveBefore).minute'));
assert.equal(r('JSON.stringify(localStorage.getItem("bdt-v1"))'),r('savesBefore'));

// Montants alignés sur les fonctions métier et sans mutation des attributs.
const job=context(),j=run(job);
j('start(0);var candidate=S.market[0],cid=candidate.id,own=club().players.find(p=>p.contractEnd<=S.season+1),ownId=own.id,snapshot=JSON.stringify(S)');
j('var recruit=forecastFinancialScenario(S,{kind:"recruit",id:cid,years:2},3),renew=forecastFinancialScenario(S,{kind:"renew",id:ownId,years:3},3),sale=forecastFinancialScenario(S,{kind:"sale",id:ownId,years:2},3),base=forecastFinancialScenario(S,{kind:"baseline"},3)');
assert.equal(j('recruit.valid'),true);
assert.equal(j('renew.valid'),true);
assert.equal(j('sale.valid'),true);
assert.equal(j('recruit.fee'),j('candidate.price'));
assert.equal(j('renew.fee'),j('contractFee(own,"renew")'));
assert.equal(j('sale.fee'),j('-transferValue(JSON.parse(JSON.stringify(own)))'));
assert.equal(j('recruit.points[0].central'),j('club().cash-candidate.price'));
assert.equal(j('renew.points[0].central'),j('club().cash-contractFee(own,"renew")'));
assert.equal(j('sale.points[0].central'),j('club().cash+transferValue(JSON.parse(JSON.stringify(own)))'));
assert.equal(j('JSON.stringify(S)'),j('snapshot'),'No scenario may change players, contracts, cash, season or markets');
assert.equal(j('recruit.annual[0].payroll-base.annual[0].payroll'),j('Math.max(askingWage(candidate,"recruit"),reservationWage(candidate,"recruit",2))*29'));
assert.equal(j('sale.annual[0].payroll-base.annual[0].payroll'),j('-own.salary*29'));
assert.ok(j('renew.annual[0].payroll>=base.annual[0].payroll'));
assert.equal(j('recruit.points[2].central-base.points[2].central'),j('-recruit.fee-(29+29)*Math.max(askingWage(candidate,"recruit"),reservationWage(candidate,"recruit",2))'));
// Un nouveau joueur engagé 1 an quitte les charges dès l'intersaison ; le
// financement de début de saison est appliqué UNE fois par année suivante.
j('var one=forecastFinancialScenario(S,{kind:"recruit",id:cid,years:1},3)');
assert.equal(j('one.annual[1].payroll'),j('base.annual[1].payroll'));
assert.equal(j('one.annual[2].payroll'),j('base.annual[2].payroll'));
assert.equal(j('base.annual[1].partners'),29*160000);
assert.equal(j('base.annual[2].partners'),29*160000);
assert.equal(j('base.points[2].central-base.points[1].central'),j('base.annual[1].partners-base.annual[1].payroll+base.annual[1].homes*375000+base.annual[1].matchDays*40000+2500000'));

// Une offre ferme est utilisée si elle est encore valide ; sinon vente
// explicitement estimée, sans créer d'acheteur imaginaire.
j('S.economy.offers.push({id:"bid-v31",buyer:1,playerId:ownId,fee:123000,expires:S.economy.week+1})');
assert.equal(j('forecastFinancialScenario(S,{kind:"sale",id:ownId,years:2},2).fee'),-123000);
assert.equal(j('forecastFinancialScenario(S,{kind:"sale",id:ownId,years:2},2).executable'),true);
j('S.economy.offers[0].expires=S.economy.week-1');
assert.equal(j('forecastFinancialScenario(S,{kind:"sale",id:ownId,years:2},2).executable'),false);

// Pénurie de liquidités et durée de retraite : mentionner le risque sans
// jamais engager un salarié, débiter la prime ou enregistrer une offre.
j('club().cash=0;var noCash=JSON.stringify(S);var unaffordable=forecastFinancialScenario(S,{kind:"recruit",id:cid,years:2},2)');
assert.equal(j('unaffordable.valid'),true);
assert.equal(j('unaffordable.executable'),false);
assert.equal(j('unaffordable.risk'),"Non exécutable à ce jour");
assert.equal(j('JSON.stringify(S)'),j('noCash'));
assert.equal(j('forecastFinancialScenario(S,{kind:"recruit",id:"missing",years:2},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"renew",id:ownId,years:0},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"renew",id:ownId,years:1},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"baseline"},0).valid'),false);

// Une action réelle garde ses contrôles : une simulation ne confirme ni ne
// modifie l'historique de négociation, même quand un accord pourrait exister.
const econ=context(),e=run(econ);
e('start(0);var p=S.market[0],id=p.id,key=talkKey(id,"recruit");negotiateContract(id,"recruit",1000,2);var tx=JSON.stringify(S.economy),ledger=JSON.stringify(S.ledger)');
e('forecastFinancialScenario(S,{kind:"recruit",id,years:2},3);financialForecastPanel()');
assert.equal(e('JSON.stringify(S.economy)'),e('tx'));
assert.equal(e('JSON.stringify(S.ledger)'),e('ledger'));
assert.equal(e('S.economy.talks[key].status'),"counter");

// Héritage V30 et temps des phases éliminatoires : les archives restent
// intouchées, y compris une rencontre suspendue et les joueurs encore liés.
const legacy=context(),l=run(legacy);
l('start(0);beginMatch();pauseMatch()');
const old=clean(l('S'));
const liveSnapshot=clean(old.live),cash=old.clubs[old.club].cash;
const restored=context(old),rr=run(restored);
assert.equal(rr('S.live.minute'),liveSnapshot.minute);
assert.equal(rr('club().cash'),cash);
assert.ok(rr('!!createSaveDocument()'));
rr('var oldS=JSON.stringify(S);var current=forecastFinancialScenario(S,{kind:"baseline"},3);var document=JSON.stringify(createSaveDocument())');
assert.equal(rr('JSON.stringify(S)'),rr('oldS'));
assert.equal(rr('parseSaveDocument(document).state.live.minute'),liveSnapshot.minute);
rr('S.phase="barrage";S.round=26;var barrage=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('barrage.annual[0].payments'),3);
rr('S.phase="semi";var semi=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('semi.annual[0].payments'),2);
rr('S.phase="final";var final=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('final.annual[0].payments'),1);
rr('S.phase="ended";var ended=forecastFinancialScenario(S,{kind:"baseline"},2)');
assert.equal(rr('ended.annual[0].payments'),0);
assert.equal(rr('ended.annual[1].payments'),29);

// Calibration déterministe multi-saisons : le scénario de base respecte les
// mêmes encaissements/décaissements fixes que le moteur (hors aléas sportifs).
const years=context(),y=run(years);
y('start(0);var starting=club().cash,startingS=S.season');
const summary=[];
for(let i=0;i<4;i++){
 y('var f=forecastFinancialScenario(S,{kind:"baseline"},3)');
 const annual=clean(y('f.annual'));
 assert.equal(annual[0].payments,29);
 assert.equal(annual[0].homes,13);
 assert.equal(annual[0].partners,29*160000);
 assert.equal(annual[0].payroll,y('totalWages()*29'));
 const now=y('club().cash'),baselineYear=annual[0];
 // Flux financiers réels : 26 semaines de championnat, sans victoire, et
 // trois journées finales sans billetterie, tous les salaires payés.
 y('var ticketTotal=0;for(let week=0;week<29;week++){S.round=Math.min(26,week);var own=week<26?S.schedule[week].find(pair=>pair.includes(S.club)):null;financeWeek(own,false);if(week<26&&own[0]===S.club)ticketTotal+=S.ledger.find(x=>x.title.includes("Billetterie")).amount;}');
 const paid=y('club().cash');
 assert.ok(paid>=baselineYear.low&&paid<=baselineYear.high);
 assert.equal(paid-now,baselineYear.partners-baselineYear.payroll+y('ticketTotal'));
 summary.push({season:y('S.season'),low:baselineYear.low,central:baselineYear.central,high:baselineYear.high,actual:paid,engineCashChange:paid-now});
 y('S.phase="ended";S.round=26;advanceSeason()');
 assert.equal(y('S.season'),i+2);
 assert.ok(y('!!createSaveDocument()'));
}
assert.equal(summary.length,4);
console.log(JSON.stringify({passed:true,years:4,summary,checks:['pure simulations and stable storage','recruit / renew / sale fee','real wage and contract horizons','partner/ticket/win bands','annual funding','cash and risk warnings','confirmed vs hypothetical sale','rejected inputs','old live saves','four seasons against financeWeek']}));
