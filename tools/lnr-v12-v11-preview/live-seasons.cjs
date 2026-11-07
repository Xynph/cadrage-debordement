'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {context}=require('../../tests/harness.cjs');
const root=path.join(__dirname,'../../dist');
function ready(saved){
 const g=context(saved);
 for(const f of ['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'])
  vm.runInContext(fs.readFileSync(path.join(root,f),'utf8'),g.ctx,{filename:f});
 return g;
}
function transfer(g){
 const document=JSON.parse(g.run('JSON.stringify(createSaveDocument())'));
 const target=ready();
 target.ctx.__doc=document;
 target.run('S=parseSaveDocument(JSON.stringify(__doc)).state');
 return target;
}
test('V12 live: asset offline 1592 IDs, 36 attributs, 11 compétences et nouveaux effectifs TOP14',()=>{
 const g=ready();
 assert.equal(g.run('Object.keys(LNR_V12_PLAYER_DATA.players).length'),1592);
 g.run("start(0,'lnr')");
 assert.equal(g.run('S.clubs.every(c=>c.players.filter(p=>p.id.startsWith("lnr:")).every(p=>p.lnrRatingsVersion===1&&p.skillBase===p.rating&&Object.keys(p.attributesV2).length===36&&Object.keys(p.skills).length===11))'),true);
 assert.equal(g.run('sheetErrors().length'),0);
 assert.equal(g.run('S.clubs.every(c=>c.players.filter(p=>p.id.startsWith("lnr:")).every(p=>p.dev.potential>=p.rating))'),true);
 assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
});
test('Trois saisons LNR reelles: moteur natif + progression unique + sauvegardes aller-retour',()=>{
 let g=ready();g.run("start(0,'lnr')");
 const starting=g.run('S.clubs[0].players.find(p=>p.lnrRatingsVersion===1).id');
 const initial=g.run('JSON.stringify(S.clubs[0].players.find(p=>p.id==='+JSON.stringify(starting)+'))');
 for(let season=1;season<=3;season++){
  assert.equal(g.run('S.season'),season);
  const outcome=g.run('(()=>{let l=createRugbyMatch([0,1],null,true),steps=0;while(!l.finished){if(++steps>5000)throw Error("Match timeout");l.paused=false;advanceRugby(l);}applyMatchInjuries(l);return l.score})()');
  assert.equal(outcome.length,2);
  g.run('S.phase="ended";S.round=26;S.live=null;');
  g.run('advanceSeason()');
  assert.equal(g.run('S.season'),season+1);
  const state=g.run('JSON.stringify(S.clubs[0].players.find(p=>p.id==='+JSON.stringify(starting)+'))');
  if(state!=='null'){
   const p=JSON.parse(state);
   assert.equal(p.age,JSON.parse(initial).age+season);
   assert.equal(p.dev.history.length,season);
   assert.equal(p.skillBase,p.rating);
   assert.equal(Object.keys(p.attributesV2).length,36);
  }
  g=transfer(g);
  assert.equal(g.run('S.season'),season+1);
  assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 }
});
test('Saison 2: age 15 accepte en historique LNR, 14 refuse, fictif 15 refuse',()=>{
 const l=ready();l.run("start(0,'lnr')");
 l.run('S.season=2;S.clubs[0].players[0].dev.history=[{season:1,age:15,start:60,end:60,minutes:0,appearances:0}]');
 assert.equal(l.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 l.run('S.clubs[0].players[0].dev.history[0].age=14');
 assert.throws(()=>l.run('createSaveDocument()'));
 const f=ready();f.run('start(0)');f.run('S.season=2;S.clubs[0].players[0].dev.history=[{season:1,age:15,start:60,end:60,minutes:0,appearances:0}]');
 assert.throws(()=>f.run('createSaveDocument()'));
});
test('Carrière fictive préexistante reste inchangée, pas de V12 ni évolution altérée',()=>{
 const g=ready();g.run('start(0)');
 assert.equal(g.run('S.clubs.every(c=>c.players.every(p=>p.lnrRatingsVersion===undefined))'),true);
 const before=JSON.parse(g.run('JSON.stringify(S)'));
 const restored=transfer(g);
 assert.equal(restored.run('S.lnrMode'),undefined);
 assert.equal(restored.run('S.clubs.every(c=>c.players.every(p=>p.lnrRatingsVersion===undefined))'),true);
 assert.equal(restored.run('S.clubs[0].players[0].rating'),before.clubs[0].players[0].rating);
});
