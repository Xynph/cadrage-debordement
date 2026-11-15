'use strict';
// Trois scénarios indépendants répartis en suites : mêmes16années et6reprises.
const assert=require('node:assert/strict'),fs=require('node:fs');
const {engineContext:context}=require('../harness.cjs');
function runScenario(name,{initialCash,years=5,checkpoints=[2,4],invest=false}){
 let game=context();let run=game.run;run('start(0)');game.deferSaves();const startCash=run('club().cash');
 if(initialCash!==undefined)run('club().cash='+JSON.stringify(initialCash));
 let valid=0,restarts=0,expenses=0;const annual=[];
 assert.equal(run('S.clubs.length'),116);
 for(let year=1;year<=years;year++){
  assert.equal(run('S.season'),year);
  if(invest&&year===1){const quote=run('worldFacilityQuote(S.club)');if(quote&&quote.affordable){const before=run('club().cash');assert.equal(run('worldUpgradeFacility()'),true);assert.equal(run('club().cash'),before-quote.cost);assert.equal(run('worldUpgradeFacility()'),false);expenses++;}}
  assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
  for(let week=0;run('S.phase')!=='ended'&&week<80;week++)run('finishRound()');
  assert.equal(run('S.phase'),'ended','saison Monde complète');
  assert.equal(run('S.season'),year);
  assert.equal(run('S.worldManagement.champion!==null'),true);
  assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
  assert.ok(run('S.worldManagement.clubInfo.every(c=>Number.isFinite(c.reputation)&&c.reputation>=0&&c.reputation<=100&&c.debt>=0)'));
  assert.ok(run('S.ledger.every(x=>Number.isFinite(x.amount))'));
  annual.push({year,cash:run('club().cash'),ledger:run('S.ledger.length'),champion:run('S.worldManagement.champion')});
  console.log('V63.2 YEAR PASS '+name+' '+year+'/'+years);
  if(year!==years){
   run('advanceSeason()');
   if(checkpoints.includes(year)){
    const saved=JSON.parse(run('JSON.stringify(S)'));const previous=game;game=context(saved);run=game.run;game.deferSaves();previous.close();restarts++;
    assert.equal(run('S.season'),year+1);
    assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);valid++;
   }
  }
 }
 assert.ok(annual.every(x=>Number.isFinite(x.cash)));
 assert.ok(run('JSON.stringify(S).length/S.clubs.length')<5000000/14,'densité brute par club sous le plafond historique');
 const final=Buffer.byteLength(run('JSON.stringify(createSaveDocument())'),'utf8');assert.ok(final<=run('worldSaveLimits(S).saveBytes'));
 const receipt={name,years,startingCash:initialCash??startCash,checkpoints:restarts,validations:valid,investments:expenses,annual,finalSaveBytes:final};
 game.close();console.log('SCENARIO PASS '+name+' '+years+' saisons, '+restarts+' reprises');return {receipt,checks:valid+years*4+3};
}

function finish(name,result,extraChecks=0){
 const report={scope:'native game engine in isolated World harness',scenarios:[result.receipt],checks:result.checks+extraChecks,passed:true,
  limits:['Not a Windows-native run','Does not replace the separate V58-V61 feature suites','RNG restarts on checkpoint so this is continuity, not bit-identical replay','One independent scenario; the three suites together cover16seasons and6checkpoints']};
 // Des fichiers distincts empêchent une suite parallèle d'écraser une autre.
 if(process.env.CD_V632_REPORT){const base=process.env.CD_V632_REPORT.replace(/\.json$/,'');fs.writeFileSync(base+'.'+name+'.json',JSON.stringify(report,null,2)+'\n');}
 console.log('V63.2 STRESS PASS '+JSON.stringify({scenario:name,scenarios:1,seasons:result.receipt.years,checkpoints:result.receipt.checkpoints,checks:report.checks}));
 return report;
}
module.exports={runScenario,finish};
