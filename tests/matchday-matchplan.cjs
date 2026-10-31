'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const t=context(),run=t.run;
for(const file of ['matchday-lineup.js','matchday-matchplan.js','matchday-center.js'])
 vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),t.ctx);
run('start(0)');
const start=run('JSON.stringify(S)'),saved=t.store['bdt-v1'];
const modes=['staff','protection','initiative'];
for(const mode of modes){
 const p=run("matchday03Proposal('"+mode+"')");
 assert.ok(p&&p.selection,'scénario '+mode);
 assert.equal(p.selection.errors.length,0,'feuille 23 valide '+mode);
 assert.equal(p.sectors.length,5,'cinq duels rugby');
 assert.ok(p.fixtures.length>=1&&p.fixtures.length<=3,'calendrier à trois rencontres maximum');
 assert.ok(run("Object.hasOwn(TACTICS,matchday03Proposal('"+mode+"').attack)"));
 assert.ok(run("Object.hasOwn(DEFENCES,matchday03Proposal('"+mode+"').defence)"));
}
assert.equal(run('JSON.stringify(S)'),start,'scénarios sans mutation');
assert.equal(t.store['bdt-v1'],saved,'scénarios sans écriture de sauvegarde');
run("nav('tactics')");
assert.match(t.app.innerHTML,/Poste de décision du manager/,'intégré dans Préparation');
assert.equal(run('JSON.stringify(S)'),start,'affichage sans mutation');
const stale=run('matchday03Token()');
run("S.tactic='large'");
assert.equal(run("matchday03Apply('protection','"+stale+"')"),false,'changement de tactique rend le scénario obsolète');
const token=run('matchday03Token()');
assert.equal(run("matchday03Apply('protection','"+token+"')"),true,'plan complet appliqué volontairement');
assert.equal(run('sheetErrors().length'),0,'feuille légale après choix');
assert.equal(run("S.defence"),'prudente','protection défensive active');
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'export de carrière compatible');
const before=run('JSON.stringify(S)');
assert.equal(run("matchday03Apply('unknown',matchday03Token())"),false,'mode inconnu refusé');
assert.equal(run('JSON.stringify(S)'),before);
run('S.live={finished:false}');
assert.equal(run("matchday03Apply('initiative',matchday03Token())"),false,'match protégé');
run('S.live=null;S.phase="ended"');
assert.equal(run("matchday03Proposal('staff')"),null,'fin de saison protégée');
console.log('matchday-matchplan: PASS (3 scénarios, 5 secteurs, 3 échéances, transaction et sauvegardes)');
