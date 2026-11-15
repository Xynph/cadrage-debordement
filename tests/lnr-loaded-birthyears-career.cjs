'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {context}=require('./harness.cjs');
function ready(snapshot){
 const g=context(snapshot);
 for(const f of ['lnr-rosters-base.js','lnr-birthyears-data.js','lnr-career.js'])vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../dist',f),'utf8'),g.ctx);
 return g;
}
test('Monde : 1592 références d’âge, calcul exact synthétique et catalogue en lecture seule',()=>{
 const g=ready(),run=g.run;
 try{
  assert.equal(run('Object.keys(LNR_BIRTHYEARS_DATA.byId).length'),1592);
  assert.equal(run('LNR_CATALOGUE.clubs.flatMap(c=>c[3]).length'),1592);
  assert.equal(run('LNR_CATALOGUE.clubs.every(c=>c[3].every(p=>!!LNR_BIRTHYEARS_DATA.byId[p[0]]))'),true);
  assert.equal(run('Object.values(LNR_BIRTHYEARS_DATA.byId).filter(x=>typeof x==="object").length'),3);
  assert.equal(run('Object.values(LNR_BIRTHYEARS_DATA.byId).every(x=>typeof x!=="string")'),true);
  // Dates inventées : les bornes avant/à/après le début de saison restent couvertes.
  for(const [date,age] of [['2006-06-30',20],['2006-07-01',20],['2006-07-02',19]]){
   g.ctx.syntheticBirth=date;
   run('LNR_BIRTHYEARS_DATA.byId["test:synthetic"]=syntheticBirth');
   assert.equal(run('lnrBirthAge("test:synthetic").age'),age);
   assert.equal(run('lnrBirthAge("test:synthetic").ageEstimated'),false);
  }
  run('delete LNR_BIRTHYEARS_DATA.byId["test:synthetic"];delete globalThis.syntheticBirth;start(0)');
  assert.equal(run('S.worldMode.version'),5);
  assert.equal(run('lnrCareerMode(S)'),false);
  assert.equal(run('S.clubs.flatMap(c=>c.players).filter(p=>p.id.startsWith("lnr:")).every(p=>p.birthYear===lnrBirthAge(p.id).birthYear)'),true);
  run("nav('team')");
  assert.doesNotMatch(g.app.innerHTML,/Catalogue LNR|Paramètres fictifs/);
  const before=run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
  run('lnrBrowseClub(17)');
  assert.equal(run('JSON.stringify(S)'),before,'la consultation ne modifie pas la carrière Monde');
  assert.equal(g.store['bdt-v1'],stored);
  assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
  const resumed=ready(JSON.parse(before));
  try{
   assert.equal(resumed.run('S.worldMode.version'),5);
   assert.equal(resumed.run('S.clubs[0].players[0].birthYear'),run('S.clubs[0].players[0].birthYear'));
   assert.ok(resumed.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
  }finally{resumed.close();}
 }finally{g.close();}
});
test('Monde : charger les références françaises conserve le mode et la sauvegarde',()=>{
 const g=ready();try{
  g.start(0);assert.equal(g.run('S.lnrMode'),undefined);assert.equal(g.run('S.worldMode.version'),5);
  const resumed=ready(g.state());try{
   assert.equal(resumed.run('S.lnrMode'),undefined);assert.equal(resumed.run('S.worldMode.version'),5);
   assert.ok(resumed.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
  }finally{resumed.close();}
 }finally{g.close();}
});
