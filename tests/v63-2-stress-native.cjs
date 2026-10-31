'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const {context}=require('./harness.cjs');
const report={scope:'native game engine in isolated harness',scenarios:[],checks:0,limits:['Not a Windows-native run','No integration of draft PR V58-V61 modules','RNG restarts on checkpoint so this is continuity, not bit-identical replay']};
function runScenario(name,{initialCash,years=5,checkpoints=[2,4],invest=false}){
 let game=context();let run=game.run;run('start(0)');const startCash=run('club().cash');
 if(initialCash!==undefined)run('club().cash='+JSON.stringify(initialCash));
 let valid=0,restarts=0,expenses=0;const annual=[];
 assert.equal(run('S.clubs.length'),14);
 for(let year=1;year<=years;year++){
  assert.equal(run('S.season'),year);
  if(invest&&year===1){const quote=run('worldFacilityQuote(S.club)');if(quote&&quote.affordable){const before=run('club().cash');assert.equal(run('worldUpgradeFacility()'),true);assert.equal(run('club().cash'),before-quote.cost);assert.equal(run('worldUpgradeFacility()'),false);expenses++;}}
  assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
  run('while(S.phase==="league")finishRound();while(S.phase!=="ended")finishRound()');
  assert.equal(run('S.season'),year);
  assert.equal(run('S.worldManagement.champion!==null'),true);
  assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
  assert.ok(run('S.worldManagement.clubInfo.every(c=>Number.isFinite(c.reputation)&&c.reputation>=0&&c.reputation<=100&&c.debt>=0)'));
  assert.ok(run('S.ledger.every(x=>Number.isFinite(x.amount))'));
  annual.push({year,cash:run('club().cash'),ledger:run('S.ledger.length'),champion:run('S.worldManagement.champion')});
  if(year!==years){
   run('advanceSeason()');
   if(checkpoints.includes(year)){
    const saved=JSON.parse(run('JSON.stringify(S)'));game=context(saved);run=game.run;restarts++;
    assert.equal(run('S.season'),year+1);
    assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
   }
  }
 }
 assert.ok(annual.every(x=>Number.isFinite(x.cash)));
 const final=run('JSON.stringify(S).length');assert.ok(final<5000000);
 report.scenarios.push({name,years,startingCash:initialCash??startCash,checkpoints:restarts,validations:valid,investments:expenses,annual,finalSaveBytes:final});
 report.checks+=valid+years*4+3;console.log('SCENARIO PASS '+name+' '+years+' saisons, '+restarts+' reprises');
}
runScenario('reference',{years:6,checkpoints:[2,4],invest:true});
runScenario('tresorerie-faible',{initialCash:100000,years:5,checkpoints:[1,3],invest:true});
runScenario('club-en-deficit',{initialCash:-250000,years:5,checkpoints:[2,4]});
const native=context();const r=native.run;r('start(0)');
const candidates=r('CDClubAI.planSeason({cash:1000000,wageRoom:4000,needs:["Pilier","Centre"],candidates:[{id:"a",pos:"Pilier",fee:100000,wage:2000,rating:80},{id:"b",pos:"Centre",fee:100000,wage:2000,rating:75}]})');assert.equal(candidates.targets.length,2);
assert.equal(r('CDClubAI.planSeason({cash:100,wageRoom:0,needs:["Pilier"],candidates:[{id:"a",pos:"Pilier",fee:100000,wage:2000,rating:80}]}).targets.length'),0);
assert.equal(r('CDCoachMarket.dismissalRisk({confidence:10,consecutiveLosses:4}).critical'),true);
report.checks+=3;report.passed=true;
if(process.env.CD_V632_REPORT)fs.writeFileSync(process.env.CD_V632_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V63.2 STRESS PASS '+JSON.stringify({scenarios:report.scenarios.length,seasons:report.scenarios.reduce((a,b)=>a+b.years,0),checkpoints:report.scenarios.reduce((a,b)=>a+b.checkpoints,0),checks:report.checks}));
