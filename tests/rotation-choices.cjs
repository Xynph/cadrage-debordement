'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const t=context(),run=t.run;
run('start(0)');
const initial=run('JSON.stringify(S)');
const model=run('squadDepthSnapshot()');
assert.equal(model.cards.length,15,'quinze postes');
assert.equal(run('JSON.stringify(S)'),initial,'consultation sans mutation');
assert.match(run('squadDepth()'),/Examiner|Aucun remplaçant frais/);
assert.equal(run('JSON.stringify(S)'),initial,'rendu sans mutation');
run('var position=0;var selected=club().players.find(p=>S.lineup.includes(p.id)&&slotEligible(p,position));');
const exists=run('!!selected');
if(exists){
 run('selected.injury=3');
 const data=run('squadDepthSnapshot().cards[0]');
 assert.ok(data.tiredStarters.some(p=>p.id===run('selected.id')),'titulaire blessé signalé');
 assert.equal(run('squadDepthSnapshot().cards[0].alternatives.every(p=>!S.lineup.includes(p.id)&&!S.reserves.includes(p.id)&&squadDepthReadiness(p).ready)'),true,'alternatives réellement disponibles');
 assert.ok(data.alert,'alerte disponible même si deux autres joueurs prêts');
}
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'sauvegarde native');
run("squadTab='depth';nav('team')");
assert.match(t.app.innerHTML,/Préparer la rotation/,'panneau natif');
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'sauvegarde après navigation');
const legacy=run(`(function(){const old=JSON.parse(JSON.stringify(createSaveDocument().state));delete old.v101to104;delete old.v105to110;delete old.v111to116;return JSON.stringify(createSaveDocument(old));})()`);
assert.equal(run(`!!parseSaveDocument(${JSON.stringify(legacy)})`),true,'ancien export rescellé sans modules V101-V116');

console.log('rotation-choices: PASS (15 postes, titulaires fragiles, alternatives, interface et sauvegarde)');
