'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const t=context(),run=t.run;
run('start(0)');
const before=run('JSON.stringify(S)');
const randomBefore=context();
randomBefore.run('start(0)');
assert.deepEqual(run('dossierScoutSignals([])'),[]);
const fixture=[
 {stats:{scrums:4,scrumsWon:2,lineouts:4,lineoutsWon:4,penalties:10}},
 {stats:{scrums:4,scrumsWon:2,lineouts:4,lineoutsWon:4,penalties:11}},
 {stats:{scrums:4,scrumsWon:2,lineouts:4,lineoutsWon:3,penalties:12}},
 {stats:null},
 {stats:{scrums:0,scrumsWon:0,lineouts:0,lineoutsWon:0}}
];
run('var scoutFixture='+JSON.stringify(fixture));
const signals=run('dossierScoutSignals(scoutFixture)');
assert.equal(signals.length,3);
assert.equal(signals[0].kind,'opportunity');
assert.equal(signals[0].slot,0);
assert.ok(signals[0].evidence.includes('6 / 12'));
assert.equal(signals[1].kind,'warning');
assert.equal(signals[1].slot,1);
assert.ok(signals[1].evidence.includes('11 / 12'));
assert.ok(signals[2].evidence.includes('33 pénalités'));
assert.ok(run('dossierScoutHTML(scoutFixture)').includes('compareDossierPosition(0)'));
assert.deepEqual(run('dossierScoutSignals([{stats:{scrums:2,scrumsWon:0}}])'),[]);
assert.deepEqual(run('dossierScoutSignals([{stats:{scrums:10,scrumsWon:11}},{stats:{scrums:10,scrumsWon:10}},{stats:{scrums:10,scrumsWon:10}}])'),[]);
assert.ok(run('dossierScoutHTML([])').includes('Aucun signal robuste'));
assert.ok(run('dossierScoutHTML([])').includes('ne modifient pas le moteur'));
run('var preview=oppositionDossierHTML()');
assert.ok(run('preview.includes("Les signaux du recruteur vidéo")'));
assert.equal(run('JSON.stringify(S)'),before,'rendu lecture seule');
assert.equal(run('Math.random()'),randomBefore.run('Math.random()'),'aucun tirage RNG');
run('var original=JSON.stringify(S);var doc=createSaveDocument()');
assert.equal(run('JSON.stringify(S)'),run('original'),'aucune mutation sauvegarde');
const restored=context();
const save=run('JSON.stringify(doc)');
restored.run('pendingSave=parseSaveDocument('+JSON.stringify(save)+');confirmSaveImport()');
assert.equal(restored.run('S.club'),run('S.club'));
assert.ok(restored.run('oppositionDossierHTML().includes("Les signaux du recruteur vidéo")'));
console.log('V62 prematch scout: observations, samples, UI, RNG, read-only save and import PASS');
