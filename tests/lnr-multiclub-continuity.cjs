'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const files=['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'];
function boot(clubId,save){
 const t=context();
 for(const name of files)vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+name,'utf8'),t.ctx);
 if(save)t.run('S=parseSaveDocument('+JSON.stringify(save)+').state');
 else t.run("start("+clubId+",'lnr')");
 return t;
}
function snap(t){
 return t.run('JSON.stringify({club:S.club,season:S.season,round:S.round,phase:S.phase,won:club().won,players:club().players.map(p=>({id:p.id,condition:p.condition,injury:p.injury,physicalLoad:p.physicalLoad}))})');
}
function saveAndReload(t,clubId){
 const before=snap(t),save=t.run('JSON.stringify(createSaveDocument())');
 assert.equal(t.run('!!parseSaveDocument('+JSON.stringify(save)+')'),true);
 const imported=boot(clubId,save);
 assert.equal(snap(imported),before,'career invariant across native save import');
 assert.equal(imported.run('S.club'),clubId,'club selection invariant');
 return imported;
}
function round(t){t.run('trainWeek();finishRound()');}
for(const clubId of [0,13]){
 test('LNR multi-club continuity and imported season rollover club '+clubId,()=>{
  let t=boot(clubId),checks=0,seasons=[];
  t=saveAndReload(t,clubId);checks++;
  for(let season=0;season<2;season++){
   let rounds=0;
   while(t.run("S.phase!=='ended'")&&rounds<14){round(t);rounds++;}
   assert.notEqual(t.run('S.phase'),'ended');
   t=saveAndReload(t,clubId);checks++;
   const before=t.run('S.round');
   round(t);rounds++;
   assert(t.run('S.round')!==before||t.run('S.phase')==='ended');
   while(t.run("S.phase!=='ended'")&&rounds<42){round(t);rounds++;}
   assert.equal(t.run('S.phase'),'ended');
   assert(rounds>=25);
   t=saveAndReload(t,clubId);checks++;
   seasons.push({season:t.run('S.season'),rounds,wins:t.run('club().won')});
   if(season===0){t.run('advanceSeason()');assert.notEqual(t.run('S.phase'),'ended');}
  }
  assert.equal(checks,5);
  assert.equal(seasons.length,2);
  assert(seasons[1].season>seasons[0].season);
  console.log(JSON.stringify({passed:true,clubId,checkpoints:checks,seasons}));
 });
}
