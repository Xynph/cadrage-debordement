'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function boot(){const t=context();for(const f of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),t.ctx);return t}
test('LNR rotation: audit longitudinal de quatre saisons, sans changement du moteur',()=>{
 const g=boot(),run=g.run;run("start(0,'lnr')");
 const yearly=[];
 for(let season=1;season<=4;season++){
  const before=run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
  const proposed=run('JSON.stringify(lnr05AdviceCandidates().map(x=>({id:x.id,score:x.score,slot:x.slot})))');
  assert.equal(run('JSON.stringify(lnr05AdviceCandidates().map(x=>({id:x.id,score:x.score,slot:x.slot})))'),proposed,'conseils déterministes');
  assert.equal(run('JSON.stringify(S)'),before,'prévisualisation sans mutation');
  assert.equal(g.store['bdt-v1'],stored,'prévisualisation sans écriture');
  assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'sauvegarde valide');
  yearly.push({season,rounds:0,injuredBefore:run('club().players.filter(p=>p.injury).length'),conditionBefore:run('club().players.reduce((n,p)=>n+p.condition,0)/club().players.length'),adviceCount:JSON.parse(proposed).length});
  while(run("S.phase!=='ended'")&&yearly.at(-1).rounds<42){run('finishRound()');yearly.at(-1).rounds++}
  assert.equal(run('S.phase'),'ended');
  assert.equal(run('lnr05AdviceCandidates().length'),0,'aucun conseil pendant saison terminée');
  assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
  yearly.at(-1).injuredAfter=run('club().players.filter(p=>p.injury).length');
  yearly.at(-1).conditionAfter=run('club().players.reduce((n,p)=>n+p.condition,0)/club().players.length');
  if(season<4)run('advanceSeason()');
 }
 console.log(JSON.stringify({passed:true,measurement:'observational only; no causal improvement claimed',yearly}));
});
