'use strict';
// Native regression: final fixtures use the real match simulator; no user save.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {engineContext:makeEngine} = require('./harness.cjs');
const temporary=new Set(),context=(...args)=>{const g=makeEngine(...args);temporary.add(g);return g;};
const {planningContext}=require('./helpers/gestion-domaines.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const settleMeetings=(g,model)=>settleClubMeetings(model,(command,payload)=>g.command(command,payload));
require('./helpers/gestion-prime.cjs').prizeContract();
const passed = [], failed = [];
function test(name, fn) {
  try { fn(); passed.push(name); console.log('PASS ' + name); }
  catch (e) { failed.push({name, error:e.message}); console.error('FAIL ' + name + ': ' + e.message); }
  finally {for(const g of temporary)g.close();temporary.clear();}
}
const data = (g, expr='S') => JSON.parse(g.run('JSON.stringify(' + expr + ')'));
function changedPaths(a,b,path='',out=[]){if(Object.is(a,b))return out;if(!a||!b||typeof a!=='object'||typeof b!=='object'){out.push(path);return out;}for(const key of new Set([...Object.keys(a),...Object.keys(b)])){if(out.length>=40)break;changedPaths(a[key],b[key],path?path+'.'+key:key,out);}return out;}
let reusable=null,initialPoint=null;const finalPoints=new Map();
function engine(){if(!reusable){reusable=makeEngine();reusable.start(0);initialPoint=reusable.checkpoint();}return reusable;}
function fresh(){const g=engine();g.restore(initialPoint);g.deferSaves();return g;}
function historical(decisions=''){const g=planningContext(null,{management:true,prepareWorld:g=>{if(decisions)g.run(decisions);}});temporary.add(g);return g;}
function valid(g){
 if(g.componentOnly){g.run('validateChampionPrize(S);componentParse(JSON.stringify(componentDocument()))');return;}
 const doc=data(g,'createSaveDocument()');g.ctx.__document=JSON.stringify(doc);
 assert.equal(g.run('parseSaveDocument(__document).checksum'),doc.checksum);delete g.ctx.__document;return doc;
}
function prepareFinal(club){
 const g=engine();g.setSeed(827381);g.start(club);g.deferSaves();
 while(!g.run('CDWorldCareer.fixtures(S).some(f=>f.competitionId==="elite"&&f.phase==="final")')){
  assert.equal(g.run('S.phase'),'league','la finale élite doit rester à jouer');
  // Contrôle des conditions, comme l’ancienne finale : les scores restent ceux
  // du véritable moteur, toutes les semaines sont réellement jouées.
  g.run('var own=nextMatch();if(own){for(const p of club().players){p.condition=S.club===0?100:25;p.injury=0;}for(const id of own)if(id!==S.club)for(const p of S.clubs[id].players)p.condition=S.club===0?25:100;autoLineup();}');
  g.week(1);
 }
 assert.equal(g.run('S.worldMode.leagues.elite.champion'),null);
 if(club===0)assert.equal(g.run('CDWorldCareer.fixtures(S).find(f=>f.competitionId==="elite"&&f.phase==="final").homeId===S.club||CDWorldCareer.fixtures(S).find(f=>f.competitionId==="elite"&&f.phase==="final").awayId===S.club'),true,'le club témoin joue la vraie finale');
 finalPoints.set(club,g.checkpoint());if(process.env.CD_CHAMPION_POINTS_DIR){fs.mkdirSync(process.env.CD_CHAMPION_POINTS_DIR,{recursive:true});fs.writeFileSync(require('node:path').join(process.env.CD_CHAMPION_POINTS_DIR,'world-final-'+club+'.json'),JSON.stringify(finalPoints.get(club)));}console.log('POINT FINALE WORLD club'+club+' semaine'+g.run('S.round'));return g;
}
function finalFixture({loser=false}={}){
 const club=loser?12:0,g=engine();if(!finalPoints.has(club))prepareFinal(club);
 const point=finalPoints.get(club);g.restore(point);assert.ok(g.run('JSON.stringify(S)')===point.text,'reprise exacte du point de finale');assert.equal(g.seed(),point.seed);g.deferSaves();
 g.run('var finalPair=CDWorldCareer.fixtures(S).find(f=>f.competitionId==="elite"&&f.phase==="final");for(const p of club().players){p.condition=S.club===0?100:25;p.injury=0;}for(const id of [finalPair.homeId,finalPair.awayId])if(id!==S.club)for(const p of S.clubs[id].players)p.condition=S.club===0?25:100;for(let i=0;i<100;i++)ledgerEntry("History "+i,0);save()');void g.store;valid(g);return g;
}
function settled(g){
 const before=g.run('club().cash');g.run('globalThis.__entriesBefore=new Set(S.ledger)');settleMeetings(g,g.command('finish_round'));
 const created=data(g,'S.ledger.filter(e=>!__entriesBefore.has(e))');delete g.ctx.__entriesBefore;
 assert.equal(g.run('S.worldMode.leagues.elite.phase'),'ended');
 assert.equal(g.run('club().cash')-before,created.reduce((n,e)=>n+e.amount,0),'Cash equals new native ledger entries');return created;
}
test('01 title with full ledger remains bounded and exports',()=>{
  const g=finalFixture();const entries=settled(g);require('./helpers/gestion-prime.cjs').worldPrizeContract(g);
  assert.equal(g.run('S.worldMode.leagues.elite.champion'),0);
  assert.equal(g.run('S.ledger.length'),100);
  assert.equal(entries.filter(e=>e.title==='Prime de champion').length,1);
  assert.equal(entries.find(e=>e.title==='Prime de champion').amount,1000000);
  valid(g);
});
test('02 automatic save after title can actually be reopened',()=>{
  const g=finalFixture();settled(g);assert.equal(g.run('lastSaveError'),false);
  const stored=JSON.parse(g.store['bdt-v1']);const h=context(stored);
  assert.ok(h.run('S'));assert.ok(h.run('JSON.stringify(S)')===g.run('JSON.stringify(S)'));valid(h);
});
test('03 confirmed import after title preserves every career field',()=>{
  const g=finalFixture();settled(g);const doc=valid(g),h=context();h.prepareCommands();
  h.ctx.__incoming=JSON.stringify(doc);const decoded=h.run('JSON.stringify(parseSaveDocument(__incoming).state)');h.command('import',{text:JSON.stringify(doc)});const imported=h.run('JSON.stringify(S)');if(imported!==decoded)console.log('IMPORT DIFF PATHS '+JSON.stringify(changedPaths(JSON.parse(decoded),JSON.parse(imported))));assert.ok(imported===decoded);valid(h);h.close();
});
test('04 repeated final settlement never credits the champion twice',()=>{
  const g=finalFixture();settled(g);const before=data(g),bytes=g.store['bdt-v1'];
  assert.equal(g.run('awardChampionPrize(S,S.worldMode.leagues.elite.champion)'),false);assert.equal(g.run('awardChampionPrize(S,S.worldMode.leagues.elite.champion)'),false);assert.ok(g.run('JSON.stringify(S)')===JSON.stringify(before));assert.equal(g.store['bdt-v1'],bytes);
});
test('05 replay after reload does not settle an ended season again',()=>{
  const g=finalFixture();settled(g);const h=context(JSON.parse(g.store['bdt-v1'])),before=data(h);
  assert.ok(before);assert.equal(h.run('awardChampionPrize(S,S.worldMode.leagues.elite.champion)'),false);assert.ok(h.run('JSON.stringify(S)')===JSON.stringify(before));valid(h);h.close();
});
test('06 old career without world/management retains the same prize rule',()=>{
 const g=historical();g.run('delete S.worldVersion;delete S.worldManagement;delete S.integratedManagementVersion;delete S.careerManagement;S.phase="ended";for(let i=0;i<100;i++)ledgerEntry("History "+i,0);var cashBefore=club().cash;awardChampionPrize(S,S.club)');
 assert.equal(g.run('S.ledger.filter(e=>e.title==="Prime de champion").length'),1);assert.equal(g.run('club().cash-cashBefore'),1000000);assert.equal(g.run('S.ledger[0].amount'),1000000);assert.equal(g.run('S.ledger.length'),100);valid(g);
 assert.equal(g.run('worldActive()'),false);assert.equal(g.run('careerIntegrated()'),false);g.close();
});
test('07 non-champion is not credited a manager prize',()=>{
  const g=finalFixture({loser:true});const entries=settled(g);
  assert.notEqual(g.run('S.worldMode.leagues.elite.champion'),12);
  assert.equal(entries.filter(e=>e.title==='Prime de champion').length,0);valid(g);
});
test('08 storage failure preserves the previous bytes and retry pays once',()=>{
 const g=finalFixture();g.command('save');const previous=g.store['bdt-v1'],before=g.run('JSON.stringify(S)'),seed=g.seed(),priorFlag=g.run('lastSaveError'),original=g.ctx.localStorage.setItem;
 try{
  g.ctx.localStorage.setItem=()=>{throw Error('Test storage failure')};
  assert.throws(()=>g.command('finish_round'),error=>error.message==='finish_round : Test storage failure');
  assert.ok(g.run('JSON.stringify(S)')===before,'refus natif : état intégral restauré');assert.equal(g.store['bdt-v1'],previous);assert.equal(g.seed(),seed);assert.equal(g.run('lastSaveError'),priorFlag);valid(g);
 }finally{g.ctx.localStorage.setItem=original;}
 const cash=g.run('club().cash');g.run('globalThis.__entriesBefore=new Set(S.ledger)');settleMeetings(g,g.command('finish_round'));
 const created=data(g,'S.ledger.filter(e=>!__entriesBefore.has(e))');delete g.ctx.__entriesBefore;
 assert.equal(g.run('club().cash')-cash,created.reduce((total,e)=>total+e.amount,0));assert.equal(created.filter(e=>e.title==='Prime de champion').length,1);assert.equal(g.run('S.championPrize.amount'),1000000);
 const paid=g.run('club().cash');assert.equal(g.run('awardChampionPrize(S,S.worldMode.leagues.elite.champion)'),false);g.command('save');
 assert.equal(g.run('lastSaveError'),false);assert.equal(g.run('club().cash'),paid);
 const h=context(JSON.parse(g.store['bdt-v1']));assert.ok(h.run('S'));valid(h);assert.equal(h.run('S.championPrize.amount'),1000000);
});
test('09 next season after a title is valid without another champion payment',()=>{
 const g=finalFixture();settled(g);g.season();const receipt=g.run('JSON.stringify(S.championPrize)'),end=g.checkpoint();console.log('PRIME NEXT '+g.run('JSON.stringify({club:S.club,season:S.season,playoff:S.playoff===null,foundation:rosterFoundationActive(S)})'));g.command('next_season',{confirmed:true});
 assert.equal(g.run('S.season'),2);assert.equal(g.run('S.phase'),'league');assert.equal(g.run('S.ledger.filter(e=>e.title==="Prime de champion").length'),1);assert.equal(g.run('JSON.stringify(S.championPrize)'),receipt);valid(g);
 // Même vrai point de clôture, puis le chemin public de changement de poste.
 g.restore(end);g.run('save()');void g.store;assert.equal(g.run('managerMobilityEnable()'),true);
 assert.equal(g.run('CDWorldCareer.edition(S).playable.filter(id=>id!==S.club).every(id=>managerMobilityDecision(id)!==null)'),true,'chaque poste World jouable reçoit une décision');for(const id of [-1,56,57,116,.5])assert.equal(g.run('managerMobilityDecision('+id+')'),null);
 const target=g.run('S.clubs.filter(c=>c.id>=58).map(c=>managerMobilityDecision(c.id)).find(candidate=>candidate?.accepted)?.clubId');assert.ok(Number.isInteger(target)&&target>=58,'candidature réelle au-delà de l’ancienne édition56');
 console.log('PRIME MOBILITY target'+target);assert.equal(g.run('managerMobilityApply('+target+')'),true);assert.equal(g.run('managerMobilityAccept("job-1-'+target+'")'),true);try{g.command('next_season',{confirmed:true});}catch(error){console.log('PRIME NEXT FAILURE '+g.run('JSON.stringify({club:S.club,season:S.season,playoff:S.playoff===null,foundation:rosterFoundationActive(S),playable:CDWorldCareer.edition(S).playable.includes(S.club),pending:S.managerMobility?.pending?.toClub})'));throw error;}
 assert.equal(g.run('S.club'),target);assert.equal(g.run('JSON.stringify(S.championPrize)'),receipt);assert.equal(g.run('S.worldMode.yearbook[0].champions.elite'),0);
 const before=g.run('JSON.stringify(S)');assert.equal(g.run('awardChampionPrize(S,0)'),false);assert.ok(g.run('JSON.stringify(S)')===before);valid(g);
 const restored=context(JSON.parse(g.store['bdt-v1']));assert.equal(restored.run('JSON.stringify(S.championPrize)'),receipt);valid(restored);
});
test('10 validator still rejects 101 entries, no enlarged limit',()=>{
  const g=fresh();g.run('for(let i=0;i<100;i++)ledgerEntry("Synthetic history",0);S.ledger.unshift({title:"Overflow",amount:0})');
  assert.throws(()=>g.run('createSaveDocument()'));assert.equal(g.run('S.ledger.length'),101);
});
for(const level of [2,3,7,10])test('forecast matches native upkeep at level '+level,()=>{
  const g=historical();g.run('worldClub(S.club).facilities='+level);
  const before=data(g),model=data(g,'careerBudgetModel()'),upkeep=g.run('worldUpkeep('+level+')');
  assert.equal(model.weeklyOtherCosts,upkeep);assert.ok(g.run('JSON.stringify(S)')===JSON.stringify(before),'Read-only forecast');
  const cash=g.run('club().cash'),projected=g.run('CDFinancePlanning.forecast({...careerBudgetModel(),weeks:1}).finalBalance');
  assert.equal(projected-cash,model.weeklyIncome-model.weeklyWages-model.weeklyOtherCosts);valid(g);g.close();
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
  assert.ok(g.run('JSON.stringify(S)')===JSON.stringify(snapshot));assert.equal(g.run('club().cash'),before-price);
  assert.equal(g.run('worldUpgradeFacility()'),false);assert.equal(g.run('club().cash'),before-price);valid(g);
});
for(const sponsor of ['prudent','performance','avance'])test('sponsor '+sponsor+' plus formation and maintenance counted once',()=>{
  const g=historical('careerSponsorPick('+JSON.stringify(sponsor)+');worldUpgradeFacility();careerSetAcademyInvestment(4000)');
  const m=data(g,'careerBudgetModel()'),cash=g.run('club().cash');
  assert.equal(m.weeklyOtherCosts,6900);
  const projected=g.run('CDFinancePlanning.forecast({...careerBudgetModel(),weeks:1}).finalBalance');
  assert.equal(projected-cash,m.weeklyIncome-m.weeklyWages-m.weeklyOtherCosts);valid(g);g.close();
});
test('20 pre-world saves keep zero additional facility charge',()=>{
  const g=historical();g.run('delete S.worldVersion;delete S.worldManagement');
  assert.equal(g.run('careerBudgetModel().weeklyOtherCosts'),0);valid(g);g.close();
});
test('21 projected alternatives keep the same maintenance baseline',()=>{
  const g=fresh();g.run('worldUpgradeFacility();careerSetAcademyInvestment(4000)');
  const a=data(g,'careerFinancialAnalysis()');assert.equal(a.base.weeklyOtherCosts,6900);
  assert.equal(a.comparison.scenarios[0].delta,-10000*a.base.weeks);
  assert.equal(a.comparison.scenarios[1].delta,-4000*a.base.weeks);
});
test('22 import preserves facility level and the derived forecast',()=>{
  const g=fresh();g.run('worldUpgradeFacility();careerSetAcademyInvestment(4000)');const doc=valid(g),h=context();
  h.prepareCommands();h.command('import',{text:JSON.stringify(doc)});
  assert.deepEqual(data(h,'careerBudgetModel()'),data(g,'careerBudgetModel()'));valid(h);
});
const report={passed:failed.length===0,groups:passed.length+failed.length,passedGroups:passed,failedGroups:failed,
  scope:'Real World finals and native persistence; historical financial formulas on guarded copied data; public prize API without management metadata',
  limitations:['Two real season preparations ending before elite finals; historical projections are not native World budgets','No Windows native test','Existing invalid saves are not silently migrated']};
if(process.env.CD_CHAMPION_BUDGET_REPORT)fs.writeFileSync(process.env.CD_CHAMPION_BUDGET_REPORT,JSON.stringify(report,null,2)+'\n');
if(reusable)reusable.close();console.log('CHAMPION BUDGET REGRESSION '+JSON.stringify({passed:report.passed,groups:report.groups,failures:failed.length}));
if(failed.length)process.exitCode=1;
