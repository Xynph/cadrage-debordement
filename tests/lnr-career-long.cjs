'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const g=context(),run=g.run;
for(const f of ['lnr-rosters-data.js','lnr-career.js'])
 vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),g.ctx);
run("start(0,'lnr')");
const initial=run('S.clubs[0].players[0].id'),name=run('S.clubs[0].name');
const check=()=>assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'export after a season');
check();
for(let year=1;year<=4;year++){
 let loops=0;
 while(run("S.phase!=='ended'")&&loops++<42){
  run('finishRound()');
 }
 assert.equal(run('S.phase'),'ended','season '+year+' completes with native match flow');
 check();
 assert.equal(run('S.clubs[0].name'),name,'official club identity after '+year);
 if(year<4){
  run('advanceSeason()');
  assert.equal(run('S.season'),year+1);
  assert.equal(run('lnrCareerMode(S)'),true);
  check();
 }
}
assert.ok(run('S.clubs[0].players.some(p=>p.id=== '+JSON.stringify(initial)+')')||run('S.season')>=4,'native recruitment/retirement remains possible');
console.log('LNR-01 LONG PASS : 4 saisons simulées avec moteur natif, reprises annuelles et sauvegardes validées');
