'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function boot(){const t=context();for(const f of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),t.ctx);t.run("start(0,'lnr')");return t}
test('LNR: le plan de repos requiert trainWeek avant la simulation de la journee',()=>{
 const untouched=boot(),rest=boot();
 const p=rest.run('club().players[0].id'),id=JSON.stringify(p);
 for(const t of [untouched,rest])t.run('club().players[0].condition=30');
 assert.equal(rest.run("setPhysicalTraining("+id+",'repos')"),true);
 assert.equal(rest.run('physicalModeFor(club().players[0],S.club)'),'repos');
 assert.equal(rest.run('club().players[0].condition'),30,'paramétrer le repos ne lance pas la séance');
 assert.equal(rest.run('S.trained'),false);
 const previous=rest.run('club().players[0].condition');
 rest.run('trainWeek()');
 assert.equal(rest.run('S.trained'),true);
 const recovered=rest.run('club().players[0].condition');
 assert(recovered>previous,'repos appliqué pendant trainWeek');
 assert.equal(rest.run("setPhysicalTraining("+id+",'normal')"),false,'choix fermé après séance');
 const untrained=untouched.run('club().players[0].condition');
 untouched.run('finishRound()');
 assert.equal(untouched.run('S.trained'),false);
 const noTraining=untouched.run('club().players[0].condition');
 assert.ok(rest.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'sauvegarde valide après séance');
 assert.ok(untouched.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'sauvegarde valide après journée');
 console.log(JSON.stringify({passed:true,mode:'training requires explicit trainWeek',player:p,conditionBefore:previous,conditionAfterTraining:recovered,conditionWithoutTrainingBefore:untrained,conditionWithoutTrainingAfterRound:noTraining}));
});
