'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function ready(){
 const g=context();
 for(const f of ['lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'])
  vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),g.ctx);
 return g;
}
test('fiche LNR: donnees sources et parametres de simulation separes et lecture seule',()=>{
 const g=ready(),run=g.run;
 run("start(0,'lnr');nav('team')");
 const id=run('LNR_CATALOGUE.clubs[0][3][0][0]');
 const before=run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
 assert.equal(run('lnrSelectPlayer('+JSON.stringify(id)+')'),true);
 assert.match(g.app.innerHTML,/Informations sourcées/);
 assert.match(g.app.innerHTML,/Identifiant LNR/);
 assert.match(g.app.innerHTML,/Paramètres fictifs du jeu — non officiels/);
 assert.match(g.app.innerHTML,/Âge au 01\/07\/2026/);
 assert.match(g.app.innerHTML,/Source des identités/);
 assert.match(g.app.innerHTML,/Note de simulation/);
 assert.equal(run('JSON.stringify(S)'),before);
 assert.equal(g.store['bdt-v1'],stored);
 assert.equal(run("lnrSelectPlayer('lnr:ID-inconnu')"),false);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 run('lnrBrowseClub(18)');
 const other=run('LNR_CATALOGUE.clubs[18][3][0][0]');
 assert.equal(run('lnrSelectPlayer('+JSON.stringify(other)+')'),true);
 assert.match(g.app.innerHTML,/Aucun indicateur de simulation/);
});
test('fiche LNR: mode fictif sans controles LNR et sauvegarde intacte',()=>{
 const g=ready(),run=g.run;run('start(0)');
 assert.equal(run('S.lnrMode'),undefined);
 assert.equal(run("lnrSelectPlayer('lnr:862')"),false);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
});
