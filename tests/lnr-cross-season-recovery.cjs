'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const modules=['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'];
function boot(document){
 const t=context();
 for(const file of modules)vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),t.ctx);
 if(document)t.run('S=parseSaveDocument('+JSON.stringify(document)+').state');
 else t.run("start(0,'lnr')");
 return t;
}
function checkpoint(t){
 const json=t.run('JSON.stringify(createSaveDocument())');
 assert.equal(t.run('!!parseSaveDocument('+JSON.stringify(json)+')'),true);
 const fresh=boot(json);
 const projection='JSON.stringify({round:S.round,phase:S.phase,club:S.club,wins:club().won,players:club().players.map(p=>({id:p.id,condition:p.condition,physicalLoad:p.physicalLoad,injury:p.injury}))})';
 assert.equal(fresh.run(projection),t.run(projection),'checkpoint retains key career and physical state');
 return fresh;
}
function advance(t){t.run('trainWeek();finishRound()');}
test('LNR native save survives midseason and endseason transitions across fresh VM contexts',()=>{
 let t=boot(),first=0,second=0;
 for(let i=0;i<14;i++){advance(t);first++;}
 assert.notEqual(t.run('S.phase'),'ended');
 t=checkpoint(t);
 while(t.run("S.phase!=='ended'")&&first<42){advance(t);first++;}
 assert.equal(t.run('S.phase'),'ended');
 assert(first>=25);
 t=checkpoint(t);
 t.run('advanceSeason()');
 assert.notEqual(t.run('S.phase'),'ended');
 assert.equal(t.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 for(let i=0;i<12;i++){advance(t);second++;}
 t=checkpoint(t);
 const before=t.run('S.round');
 advance(t);second++;
 assert(t.run('S.round')!==before||t.run('S.phase')==='ended','reloaded next season advances');
 while(t.run("S.phase!=='ended'")&&second<42){advance(t);second++;}
 assert.equal(t.run('S.phase'),'ended');
 assert(second>=25);
 const end=checkpoint(t);
 assert.equal(end.run('S.phase'),'ended');
 console.log(JSON.stringify({passed:true,seasons:2,rounds:[first,second],checkpoints:4,reloadedSeasonEnd:true,readableSaveAfterResume:true}));
});
