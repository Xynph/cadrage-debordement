'use strict';
const assert=require('node:assert/strict');
const {planningContext:context}=require('./helpers/gestion-domaines.cjs');
const {engineContext}=require('./harness.cjs');
const storageSnapshot=t=>t.storageText?t.storageText():t.store['bdt-v1'];
const clean=obj=>JSON.parse(JSON.stringify(obj));
const equal=(a,b)=>assert.deepEqual(clean(a),clean(b));
const run=t=>t.run;

// Simulations de trésorerie : la fonction est strictement pure, même en match en cours.
(()=>{
const fresh=context(),r=run(fresh);
r('var before=JSON.stringify(S),rngBefore=Math.random()');
const beforeStorage=storageSnapshot(fresh);
r('var baseline=forecastFinancialScenario(S,{kind:"baseline"},3),again=forecastFinancialScenario(S,{kind:"baseline"},3),html=finance()');
equal(r('baseline'),r('again'));
assert.ok(r('html.includes("Prévoir sans engager le club")'));
assert.ok(r('html.includes("Hypothèses, limites et calendrier")'));
assert.ok(r('JSON.stringify(S)')===r('before'));
assert.equal(storageSnapshot(fresh),beforeStorage);
assert.equal(r('baseline.points.length'),4);
assert.equal(r('baseline.annual[0].payments'),29);
assert.equal(r('baseline.annual[0].partners'),29*160000);
assert.equal(r('baseline.annual[0].homes'),13);
assert.equal(r('baseline.annual[0].matchDays'),26);
assert.equal(r('baseline.annual[0].payroll'),r('totalWages()*29'));
assert.equal(r('baseline.points[0].central'),r('club().cash'));
assert.equal(r('baseline.annual[0].central-baseline.annual[0].low'),r('13*75000+26*40000'));
assert.equal(r('baseline.annual[0].high-baseline.annual[0].central'),r('13*75000+26*40000'));
const savesBefore=storageSnapshot(fresh);
r('S.live={minute:0,paused:true};var liveBefore=JSON.stringify(S.live);financialForecastPanel();forecastFinancialScenario(S,{kind:"baseline"},3)');
assert.equal(r('JSON.stringify(S.live)'),r('liveBefore'));
assert.equal(storageSnapshot(fresh),savesBefore);
assert.equal(r('setForecastChoice("unknown","recruit")'),false);
assert.equal(r('setForecastChoice("years",9)'),false);
assert.equal(r('setForecastChoice("horizon",-1)'),false);
assert.equal(r('setForecastChoice("horizon",2)'),true);
assert.equal(r('S.live.minute'),r('JSON.parse(liveBefore).minute'));
assert.equal(storageSnapshot(fresh),savesBefore);

// Montants alignés sur les fonctions métier et sans mutation des attributs.

fresh.close();
})();
(()=>{
const job=context(),j=run(job);
j('var candidate=S.market[0],cid=candidate.id,own=club().players.find(p=>p.contractEnd<=S.season+1),ownId=own.id,snapshot=JSON.stringify(S)');
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
assert.ok(j('JSON.stringify(S)')===j('snapshot'),'No scenario may change players, contracts, cash, season or markets');
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
assert.ok(j('JSON.stringify(S)')===j('noCash'));
assert.equal(j('forecastFinancialScenario(S,{kind:"recruit",id:"missing",years:2},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"renew",id:ownId,years:0},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"renew",id:ownId,years:1},2).valid'),false);
assert.equal(j('forecastFinancialScenario(S,{kind:"baseline"},0).valid'),false);

// Une action réelle garde ses contrôles : une simulation ne confirme ni ne
// modifie l'historique de négociation, même quand un accord pourrait exister.

job.close();
})();
(()=>{
const econ=engineContext(),e=run(econ);econ.start(0);
e('var p=S.market.find(p=>reservationWage(p,"recruit",2)>1000),id=p.id,key=talkKey(id,"recruit");negotiateContract(id,"recruit",1000,2);var tx=JSON.stringify(S.economy),ledger=JSON.stringify(S.ledger)');
e('forecastFinancialScenario(S,{kind:"recruit",id,years:2},3);financialForecastPanel()');
assert.equal(e('JSON.stringify(S.economy)'),e('tx'));
assert.equal(e('JSON.stringify(S.ledger)'),e('ledger'));
assert.equal(e('S.economy.talks[key].status'),"counter");
// Le bornage du vrai journal natif est reçu séparément des projections historiques.
e('for(var i=0;i<120;i++)ledgerEntry("Contrôle du journal natif",0);save()');assert.equal(e('S.ledger.length'),100);assert.ok(e('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));

// Héritage V30 et temps des phases éliminatoires : les archives restent
// intouchées, y compris une rencontre suspendue et les joueurs encore liés.

econ.close();
})();
(()=>{
const legacy=engineContext(),l=run(legacy);legacy.start(0);legacy.deferSaves();legacy.toMatch();
l('beginMatch();pauseMatch()');
const old=clean(l('S'));
const liveSnapshot=clean(old.live),cash=old.clubs[old.club].cash;
const restored=engineContext(old),real=run(restored);
assert.equal(real('S.live.minute'),liveSnapshot.minute);
assert.equal(real('club().cash'),cash);
assert.ok(real('!!createSaveDocument()'));
real('var oldS=JSON.stringify(S);var current=forecastFinancialScenario(S,{kind:"baseline"},3);var document=JSON.stringify(createSaveDocument())');
assert.ok(real('JSON.stringify(S)')===real('oldS'));
assert.equal(real('parseSaveDocument(document).state.live.minute'),liveSnapshot.minute);
// Phases du format financier historique : données seules, jamais une horloge World.

legacy.close();restored.close();
})();
(()=>{
const phases=context(),rr=run(phases);
rr('S.phase="barrage";S.round=26;var barrage=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('barrage.annual[0].payments'),3);
rr('S.phase="semi";var semi=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('semi.annual[0].payments'),2);
rr('S.phase="final";var final=forecastFinancialScenario(S,{kind:"baseline"},1)');
assert.equal(rr('final.annual[0].payments'),1);
rr('S.phase="ended";var ended=forecastFinancialScenario(S,{kind:"baseline"},2)');
assert.equal(rr('ended.annual[0].payments'),0);
assert.equal(rr('ended.annual[1].payments'),29);

// Calibration pure du modèle historique sur quatre années d’entrée : le scénario de base respecte les
// mêmes encaissements/décaissements fixes que le moteur (hors aléas sportifs).

phases.close();
})();
(()=>{
const years=context(),y=run(years);
y('var starting=club().cash,startingS=S.season');
const summary=[];
for(let i=0;i<4;i++){
 y('var f=forecastFinancialScenario(S,{kind:"baseline"},3)');
 const annual=clean(y('f.annual'));
 assert.equal(annual[0].payments,29);
 assert.equal(annual[0].homes,13);
 assert.equal(annual[0].partners,29*160000);
 assert.equal(annual[0].payroll,y('totalWages()*29'));
 const now=y('club().cash'),baselineYear=annual[0];
 // Flux d’entrée de la projection :26 périodes régulières, sans victoire, et
 // trois périodes finales sans billetterie ; aucune financeWeek native comparée.
 y('var ticketTotal=0;for(let week=0;week<26;week++){const own=S.schedule[week].find(pair=>pair.includes(S.club));if(own[0]===S.club)ticketTotal+=rand(300,450)*1000;}var sampled=CDFinancePlanning.forecast({cash:club().cash,weeklyIncome:160000,weeklyWages:totalWages(),oneOffIncome:ticketTotal,weeks:29});club().cash=sampled.finalBalance');
 const paid=y('club().cash');
 assert.ok(paid>=baselineYear.low&&paid<=baselineYear.high);
 assert.equal(paid-now,baselineYear.partners-baselineYear.payroll+y('ticketTotal'));
 summary.push({season:y('S.season'),low:baselineYear.low,central:baselineYear.central,high:baselineYear.high,sampled:paid,sampleCashChange:paid-now});
 y('componentPlanningYear()');
 assert.equal(y('S.season'),i+2);
 assert.ok(y('S.ledger.length<=100'),'The real interseason funding must respect the save ledger limit');
 assert.ok(y('!!componentParse(JSON.stringify(componentDocument()))'));
}
assert.equal(summary.length,4);
console.log(JSON.stringify({passed:true,years:4,scope:'historical financial model; native World effects and exports checked separately',summary,checks:['pure simulations and stable storage','recruit / renew / sale fee','historical wage and contract horizons','partner/ticket/win bands','annual funding','cash and risk warnings','confirmed vs hypothetical sale','rejected inputs','old live saves','four historical input years against public pure finance planning']}));

years.close();
})();
