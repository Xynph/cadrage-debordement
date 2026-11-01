'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const {context}=require('./harness.cjs');
const dist=path.resolve(__dirname,'../dist');
function ready(snapshot){
 const g=context(snapshot);
 for(const f of ['lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'])
  vm.runInContext(fs.readFileSync(path.join(dist,f),'utf8'),g.ctx);
 return g;
}
test('LNR: 1592 années chargées, trois dates exactes et catalogue en lecture seule',()=>{
 const g=ready(),run=g.run;
 assert.equal(run('Object.keys(LNR_BIRTHYEARS_DATA.byId).length'),1592);
 assert.equal(run('LNR_CATALOGUE.clubs.flatMap(c=>c[3]).length'),1592);
 assert.equal(run('LNR_CATALOGUE.clubs.every(c=>c[3].every(p=>!!LNR_BIRTHYEARS_DATA.byId[p[0]]))'),true);
 for(const [id,date] of [['lnr:13725','2007-03-10'],['lnr:13497','2005-01-01'],['lnr:11779','2003-02-14']]){
  assert.equal(run('LNR_BIRTHYEARS_DATA.byId['+JSON.stringify(id)+']'),date);
  assert.equal(run('lnrBirthAge('+JSON.stringify(id)+').ageEstimated'),false);
 }
 run("start(0,'lnr')");
 assert.equal(run('lnrCareerMode(S)'),true);
 assert.equal(run('S.clubs[0].players.filter(p=>p.id.startsWith("lnr:")).every(p=>p.birthYear===Number(String(LNR_BIRTHYEARS_DATA.byId[p.id]).slice(0,4)))'),true);
 run("nav('team')");
 assert.match(g.app.innerHTML,/Âge au 01\/07\/2026/);
 const before=run('JSON.stringify(S)');
 run('lnrBrowseClub(17)');
 assert.equal(run('JSON.stringify(S)'),before,'browsing must not mutate career');
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 const resumed=ready(JSON.parse(before));
 assert.equal(resumed.run('lnrCareerMode(S)'),true);
 assert.equal(resumed.run('S.clubs[0].players[0].birthYear'),run('S.clubs[0].players[0].birthYear'));
 assert.ok(resumed.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
});
test('univers fictif et sauvegarde historique inchangés avec données LNR chargées',()=>{
 const g=ready(),run=g.run;
 run('start(0)');
 assert.equal(run('S.lnrMode'),undefined);
 const legacy=JSON.parse(run('JSON.stringify(S)'));
 const resumed=ready(legacy);
 assert.equal(resumed.run('S.lnrMode'),undefined);
 assert.ok(resumed.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
});
