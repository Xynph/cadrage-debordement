'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const t=context(),run=t.run;
for(const file of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])
 vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),t.ctx);
run("start(0,'lnr')");
for(let year=1;year<=4;year++){
 const previous=run('JSON.stringify(S)');
 run("lnr05FilterBy('evidence')");
 run('lnr05View()');
 assert.equal(run('JSON.stringify(S)'),previous,'evidence panel does not mutate in season '+year);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'valid snapshot in season '+year);
 let steps=0;
 while(run("S.phase!=='ended'")&&steps++<42)run('finishRound()');
 assert.equal(run('S.phase'),'ended');
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 assert.equal(run('lnr05Enabled()'),true);
 if(year<4)run('advanceSeason()');
}
console.log('LNR05 LONG PASS: 4 seasons, evidence stable, native save compatible');
