'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function ready(){
 const g=context();for(const f of ['lnr-rosters-base.js','lnr-birthyears-data.js','lnr-career.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),g.ctx);g.start(0);return g;
}
test('Monde : références françaises consultatives, adaptateur historique bloqué',()=>{
 const g=ready(),run=g.run;try{
  run("nav('team')");
  const before=run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
  const id=run('LNR_CATALOGUE.clubs[0][3][0][0]');
  assert.equal(run('lnrSelectPlayer('+JSON.stringify(id)+')'),false,'aucune ouverture de l’ancienne carrière');
  // Le rendu des références reste un test pur ; il ne s’injecte pas dans l’interface Monde.
  const facts=run('lnrPlayerFacts(LNR_CATALOGUE.clubs[0],LNR_CATALOGUE.clubs[0][3][0])');
  for(const label of [/Informations sourcées/,/Identifiant LNR/,/Paramètres fictifs du jeu — non officiels/,/Âge au 01\/07\/2026/,/Source des identités/,/Note de simulation/])assert.match(facts,label);
  assert.doesNotMatch(g.app.innerHTML,/Informations sourcées|Paramètres fictifs/);
  assert.equal(run('JSON.stringify(S)'),before);assert.equal(g.store['bdt-v1'],stored);
  assert.equal(run("lnrSelectPlayer('lnr:ID-inconnu')"),false);
  assert.equal(run('lnrPlayerFacts(LNR_CATALOGUE.clubs[0],null)'), '');
  assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
  run('lnrBrowseClub(18)');
  const other=run('lnrPlayerFacts(LNR_CATALOGUE.clubs[18],LNR_CATALOGUE.clubs[18][3][0])');
  assert.match(other,/Note de simulation/,'les trente clubs sont maintenant dans la carrière Monde');
  assert.equal(run('JSON.stringify(S)'),before);assert.equal(g.store['bdt-v1'],stored);
  // Profil absent : même absence d’indicateur que l’ancien club hors périmètre.
  run('LNR_BIRTHYEARS_DATA.byId["test:absent"]=2000');
  assert.match(run('lnrPlayerFacts(LNR_CATALOGUE.clubs[18],["test:absent","Profil de recette","Centre",""])'),/Aucun indicateur de simulation/);
  run('delete LNR_BIRTHYEARS_DATA.byId["test:absent"]');
 }finally{g.close();}
});
test('Monde : aucun contrôle LNR hérité, sauvegarde valide',()=>{
 const g=ready();try{
  assert.equal(g.run('S.lnrMode'),undefined);assert.equal(g.run('S.worldMode.version'),5);
  assert.equal(g.run("lnrSelectPlayer('lnr:862')"),false);
  assert.ok(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 }finally{g.close();}
});
