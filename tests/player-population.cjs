'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const valid=r=>r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))');

test('new careers enable player renewal; old AI roster saves remain unchanged until explicit opt-in',()=>{
 const h=context(),r=h.run;r('start(0)');
 assert.equal(r('S.aiRosterVersion'),2);
 assert.equal(r('aiRosterPopulationActive()'),true);
 const historical=context(),hr=historical.run;
 hr('var setupNew=aiRosterSetup;aiRosterSetup=function(){var result=setupNew();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};start(0)');
 const old=hr('JSON.stringify(S)'),legacy=context(JSON.parse(old)),l=legacy.run;
 assert.equal(l('aiRosterPopulationActive()'),false);
 assert.equal(l('JSON.stringify(S)'),old);
 assert.equal(valid(l),true);
 l('S.live={};');assert.equal(l('enablePopulationPolicy()'),false);l('S.live=null');
 const ids=l('JSON.stringify(S.clubs.map(c=>c.players.map(p=>p.id)))'),cash=l('JSON.stringify(S.clubs.map(c=>c.cash))');
 assert.equal(l('enablePopulationPolicy()'),true);
 assert.equal(l('JSON.stringify(S.clubs.map(c=>c.players.map(p=>p.id)))'),ids);
 assert.equal(l('JSON.stringify(S.clubs.map(c=>c.cash))'),cash);
 assert.equal(valid(l),true);
});

test('academy graduates stay available with their identity and retain development history',()=>{
 const h=context(),r=h.run;r('start(0);S.season=2;S.round=0;var a=aiRosterAcademy(S.clubs[1]);var p=academyPlayer(1,9,1,999);p.age=21;p.dev.retireAge=37;a.players.push(p);var id=p.id;var beforeName=p.name;aiRosterYouthIntake();aiRosterPrepareMarket();S.market=aiRosterMarketPool([])');
 assert.equal(r('a.players.some(x=>x.id===id)'),false);
 assert.equal(r('S.economy.freeAgents.some(x=>x.id===id)'),true);
 assert.equal(r('S.market.find(x=>x.id===id).name'),r('beforeName'));
 assert.equal(r('S.market.find(x=>x.id===id).age'),22);
 assert.equal(r('S.market.find(x=>x.id===id).population.origin'),'academy');
 assert.ok(r('S.market.find(x=>x.id===id).dev.history.length')>0);
 assert.equal(valid(r),true);
});

test('small-club emergence fills missing positions once and persists across market refreshes',()=>{
 const h=context(),r=h.run;r('start(0);S.market=[];S.economy.freeAgents=[];S.aiRoster.population.lastPoolSeason=0;aiRosterPrepareMarket();var first=JSON.stringify(S.economy.freeAgents);var ids=S.economy.freeAgents.map(p=>p.id);aiRosterPrepareMarket()');
 assert.equal(r('JSON.stringify(S.economy.freeAgents)'),r('first'));
 assert.ok(r('S.economy.freeAgents.length')>=20);
 assert.equal(r('POS.every((_,slot)=>S.economy.freeAgents.some(p=>slotEligible(p,slot)))'),true);
 assert.equal(r('S.economy.freeAgents.every(p=>p.population.origin==="small-club"&&p.age>=18&&p.age<=26&&p.age<p.dev.retireAge)'),true);
 r('S.market=aiRosterMarketPool([])');assert.equal(r('JSON.stringify(S.market.map(p=>p.id))'),r('JSON.stringify(ids)'));
 assert.equal(valid(r),true);
});

test('renewal promotes qualified academy depth with real wage constraints',()=>{
 const h=context(),r=h.run;r('start(0);S.season=2;S.round=0;var c=S.clubs[1];c.players=c.players.slice(0,27);c.cash=10000000;var a=aiRosterAcademy(c);for(let i=0;i<30;i++){let p=academyPlayer(c.id,i%15,1,700+i);p.age=19;p.dev.retireAge=37;a.players.push(p)};var previousCash=c.cash;aiRosterYouthIntake()');
 assert.ok(r('c.players.length')>=35,'healthy depth must grow beyond emergency-only coverage');
 assert.ok(r('c.players.length')<=40);
 assert.equal(r('new Set(c.players.map(p=>p.id)).size'),r('c.players.length'));
 assert.equal(r('c.cash'),r('previousCash'));
 assert.equal(valid(r),true);
});

test('new policy rejects corrupt origin, duplicated pool ownership and unbounded pool state',()=>{
 const h=context(),r=h.run;r('start(0);aiRosterPrepareMarket();S.market=aiRosterMarketPool([])');
 r('S.economy.freeAgents[0].population.origin="invented"');assert.throws(()=>r('validateCareer(S)'));
 r('S.economy.freeAgents[0].population.origin="small-club";S.clubs[1].players.push(S.economy.freeAgents[0])');assert.throws(()=>r('validateCareer(S)'));
});

test('available population is bounded, compensates departures and records excess returning to the small-club pool',()=>{
 const h=context(),r=h.run;r('start(0);S.season=3;S.aiRoster.population.lastPoolSeason=2;var wanted=S.aiRoster.population.referenceAccessible;S.clubs[1].players=S.clubs[1].players.slice(0,15);S.economy.freeAgents=[];S.market=[];aiRosterPrepareMarket()');
 assert.ok(r('aiRosterAccessibleCount()')>=r('wanted'));
 r('for(let i=0;i<400;i++){let p=aiRosterSmallClubPlayer(i%15,1000+i);p.id="historic-released-"+i;p.population={version:1,origin:"released",season:1,availableSince:1,clubId:null};p.contractEnd=null;S.economy.freeAgents.push(p)};aiRosterTrimFreeAgents();S.market=aiRosterMarketPool([])');
 assert.equal(r('S.economy.freeAgents.length'),r('aiRosterFreeAgentLimit()'));
 assert.ok(r('S.aiRoster.population.history.find(x=>x.season===3).departed')>0);
 assert.equal(r('new Set(S.economy.freeAgents.map(p=>p.id)).size'),r('S.economy.freeAgents.length'));
 assert.equal(valid(r),true);
});

test('human academy graduates retain their identity and become recruitable at 22',()=>{
 const h=context(),r=h.run;r('start(0);var p=academyPlayer(S.club,9,1,991);p.age=21;p.dev.retireAge=37;S.development.academy.push(p);var id=p.id;rollDevelopmentYear()');
 assert.equal(r('S.development.academy.some(p=>p.id===id)'),false);
 assert.equal(r('S.economy.freeAgents.some(p=>p.id===id&&p.age===22&&p.population.origin==="academy")'),true);
 r('S.market=aiRosterMarketPool([])');assert.equal(r('S.market.find(p=>p.id===id).id'),r('id'));
 assert.equal(valid(r),true);
});

test('market identities are canonical and minor reserves are not accessible adults',()=>{
 const h=context(),r=h.run;r('start(0);S.market=JSON.parse(JSON.stringify(S.market));S.market[0].rating++');
 assert.throws(()=>r('validateCareer(S)'));
 r('S.market=aiRosterMarketPool([]);var p=JSON.parse(JSON.stringify(S.economy.freeAgents[0]));p.id="minor-reserve";p.age=17;p.population.origin="released";S.economy.freeAgents.push(p);var id=p.id;var adultBefore=aiRosterAccessibleCount();S.market=aiRosterMarketPool([])');
 assert.equal(r('S.market.some(p=>p.id===id)'),false);
 assert.equal(valid(r),true);
 r('S.economy.freeAgents.find(p=>p.id===id).age=18');assert.equal(r('aiRosterAccessibleCount()'),r('adultBefore+1'));
 r('S.market=aiRosterMarketPool([]);delete S.market.find(p=>p.id.startsWith("small-")).population');assert.throws(()=>r('validateCareer(S)'));
});

test('retired IDs cannot coexist with player populations and reordered JSON keys stay valid',()=>{
 const h=context(),r=h.run;r('start(0);S.market=S.market.map(p=>Object.fromEntries(Object.entries(p).reverse()))');
 assert.equal(valid(r),true);
 r('var p=S.market[0];S.development.retired.push({id:p.id,name:p.name,age:38,season:1,club:"Agent libre",minutes:0})');
 assert.throws(()=>r('validateCareer(S)'));
});
