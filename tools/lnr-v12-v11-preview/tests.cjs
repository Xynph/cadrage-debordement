'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),vm=require('node:vm');
const B=require('./bridge.cjs'),C=require('../rugby-real-v12/review.cjs');
const {context}=require('../../tests/harness.cjs');
const master=require('../../modding/data06/rugby-master-2026-2027.json');
const report=require('../../data/scouting/review-v12/candidate.json');
const verified=JSON.stringify(master);
let memo;
function data(){return memo||(memo=B.candidate(master,report));}
function live(saved){
 const g=context(saved);
 for(const f of ['lnr-rosters-data.js','lnr-career.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../../dist',f),'utf8'),g.ctx);
 return g;
}
test('1 592 identités, notes V12 et profondeur douce sur copies seulement',()=>{
 const r=data();assert.equal(r.master.players.length,1592);assert.equal(r.tiers.length,1592);
 assert.equal(JSON.stringify(master),verified);
 assert.equal(r.changes.length,1592);
 assert.deepEqual(Object.values(r.weights),[4,2,-3,-5]);
});
test('1 592 projections natives sans bonus initial et potentiel historique conservé',()=>{
 const r=data();
 for(const p of r.master.players){
  const source=master.players.find(q=>q.id===p.id);
  const b={id:p.id,age:p.ageApprox,pos:'Centre',fam:7,rating:55,condition:100,injury:0,salary:5000};
  const n=B.playerForNative(b,p);
  assert.deepEqual(n.skills,C.project(p));
  assert.equal(n.rating-n.skillBase,0);
  assert.equal(n.potential,source.potential);
  assert.deepEqual(n.hiddenTraitsV2,source.hiddenTraitsV2);
  assert.ok(n.previewDevCeiling>=n.rating&&n.previewDevCeiling<=99);
 }
 assert.equal(JSON.stringify(master),verified);
});
test('vraie carrière LNR: feuille complète, 11 compétences, sauvegarde et match natif',()=>{
 const g=live();g.run("start(0,'lnr')");
 const initial=g.run('JSON.stringify(S)'),initialParsed=JSON.parse(initial),r=data();
 const selection=new Map(r.master.players.map(p=>[p.id,p]));
 let linked=0;
 for(let i=0;i<14;i++){
  const before=JSON.parse(g.run('JSON.stringify(S.clubs['+i+'].players)'));
  const subset=before.map(p=>selection.get(p.id)).filter(Boolean);
  const after=B.alignRoster(before,subset);
  for(const player of after)if(player.lnrRatingsPreview){
   B.initDevelopment(player,p=>{g.ctx.__initPlayer=p;g.run('ensureDevelopment(__initPlayer)');});
   assert.equal(player.dev.potential,Math.max(player.rating,Math.min(99,player.dev.potential)));
   linked++;
  }
  g.ctx.__replacement=after;
  g.run('S.clubs['+i+'].players=__replacement');
 }
 assert.equal(linked,initialParsed.clubs.flatMap(c=>c.players).filter(p=>p.id.startsWith('lnr:')).length);
 assert.equal(g.run('sheetErrors().length'),0);
 assert.equal(g.run('S.clubs.every(c=>c.players.filter(p=>p.id.startsWith("lnr:")).every(p=>p.rating===p.skillBase && !!p.skills))'),true);
 assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 const doc=JSON.parse(g.run('JSON.stringify(createSaveDocument())'));
 const again=live();again.ctx.__exportDoc=doc;
 again.run('S=parseSaveDocument(JSON.stringify(__exportDoc)).state');
 assert.equal(again.run('S.lnrMode.snapshot'),'2026-10-31');
 assert.equal(again.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 assert.equal(again.run('S.clubs[0].players.filter(p=>p.lnrRatingsPreview).every(p=>p.rating===p.skillBase)'),true);
 g.run('S.phase="regular";S.club=0;S.live=null;');
 const match=g.run('createRugbyMatch([0,1],null,true)');
 assert.equal(match.engine,2);
 g.ctx.__game=match;
 const final=g.run('(()=>{let l=__game,steps=0;while(!l.finished){if(++steps>5000)throw Error("Timeout");l.paused=false;advanceRugby(l);}applyMatchInjuries(l);return {score:l.score,tries:l.tries,engine:l.engine}})()');
 assert.equal(final.engine,2);assert.equal(final.score.length,2);
 assert.equal(JSON.stringify(master),verified);
});
test('courbes V11: progression annuelle unique, idempotence, physique et potentiel',()=>{
 const root=process.env.CD_V11_ROOT;
 if(!root)throw Error('CD_V11_ROOT required by dedicated integration CI');
 const age=require(path.resolve(root,'tools/rugby-real-v11/aging.cjs'));
 const r=data().master.players.find(p=>p.ageApprox>=22&&p.ageApprox<=28);
 const native=B.playerForNative({id:r.id,age:r.ageApprox,pos:'Centre',fam:7,rating:62,condition:100,injury:0},r);
 const initial={playerId:r.id,age:native.age,season:1,lastSeason:null};
 const a=B.evolveOnce(native,initial,{minutes:1500,training:.9},age.step);
 assert.equal(a.player.age,native.age+1);assert.equal(a.player.rating-a.player.skillBase,0);
 assert.equal(a.player.potential,native.potential);
 assert.deepEqual(a.player.hiddenTraitsV2,native.hiddenTraitsV2);
 assert.deepEqual(a.player.skills,C.project(a.player));
 const again=B.evolveOnce(a.player,{...a.state},{minutes:1500,training:.9},age.step);
 assert.deepEqual(again.player,a.player);
 assert.equal(again.changes.length,0);
 assert.throws(()=>B.evolveOnce(a.player,{...a.state,season:0},{},age.step),/season/);
});
test('ancienne sauvegarde fictive native toujours valide, aucun upgrade rétroactif',()=>{
 const old=live();old.run('start(0)');
 const saved=JSON.parse(old.run('JSON.stringify(S)')),restored=live(saved);
 assert.equal(restored.run('S.lnrMode'),undefined);
 assert.equal(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 assert.equal(JSON.stringify(master),verified);
});
