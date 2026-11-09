'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const file=path.join(__dirname,'../native/engine/performance-analysis.cjs');
assert.ok(fs.existsSync(file),'Le domaine consultatif des analyses doit exister.');
const domain=require(file);
const stats=(n=10)=>({lineouts:n,lineoutsWon:n-2,scrums:5,scrumsWon:4,penalties:9});
const row=(i,extra={})=>({pair:i%2?[1,0]:[0,1],score:i%2?[10,20]:[20,10],tries:i%2?[1,2]:[2,1],round:i,phase:'league',stats:[stats(),stats()],...extra});
const state=history=>({club:0,season:3,round:7,clubs:[{id:0,name:'Notre club'},{id:1,name:'Adversaire'},{id:2,name:'Autre'}],history});
function project(s){const json=JSON.stringify(s),ctx=vm.createContext({S:s});vm.runInContext('globalThis.d=('+domain.factory.toString()+')()',ctx);const value=JSON.parse(JSON.stringify(ctx.d.project()));assert.equal(JSON.stringify(s),json,'La projection ne modifie pas le moteur.');return value;}
let p=project(state(Array.from({length:8},(_,i)=>row(i))));
assert.deepEqual(p.matches.map(x=>x.round),[7,6,5,4,3]);
assert.equal(p.summary.played,5);assert.equal(p.summary.won,5);assert.equal(p.summary.pointsFor,100);assert.equal(p.summary.pointsAgainst,50);
assert.equal(p.metrics.lineouts.attempts,50);assert.equal(p.metrics.lineouts.won,40);assert.equal(p.metrics.lineouts.rate,.8);
assert.equal(p.comparison.recent.count,3);assert.equal(p.comparison.previous.count,2);assert.equal(p.comparison.pointsAgainstDelta,0);
assert.ok(p.advice.some(x=>x.key==='discipline'&&x.evidence.includes('45')));
p=project(state([row(0,{stats:undefined}),row(1,{stats:[{},{}]}),row(2,{stats:[{lineouts:0,lineoutsWon:0},stats()]})]));
assert.equal(p.metrics.lineouts.rate,null);assert.equal(p.metrics.lineouts.matches,1);assert.equal(p.metrics.penalties.matches,0);assert.equal(p.metrics.penalties.average,null);assert.equal(p.comparison,null);assert.equal(p.advice.length,0);
p=project(state([row(0,{stats:[{lineouts:2,lineoutsWon:3,penalties:NaN},stats()]})]));
assert.equal(p.metrics.lineouts.matches,0);assert.equal(p.metrics.penalties.matches,0);
p=project(state([row(0,{season:2}),row(1,{pair:[1,2]}),row(2,{pair:[0,1],score:[15,15],winner:0}),row(3,{pair:[1,0],score:[15,15],winner:1})]));
assert.equal(p.summary.played,2);assert.equal(p.summary.won,1);assert.equal(p.summary.lost,1);assert.equal(p.summary.drawn,0);assert.equal(p.matches[0].decidedAfterTie,true);
p=project(state([row(0,{stats:[stats(2),stats()]}),row(1,{stats:[stats(),stats(18)]})]));
assert.equal(p.metrics.lineouts.rate,16/20,'Le taux est un ratio pondéré des tentatives et non une moyenne de pourcentages.');
assert.equal(project(null).available,false);assert.equal(project(state([])).summary.played,0);
assert.deepEqual(domain.commands,[]);assert.deepEqual(domain.files,[]);
p=project(state([row(20,{week:20,competitionRound:7,neutral:true})]));
assert.equal(p.matches[0].competitionRound,7);assert.equal(p.matches[0].week,20);assert.equal(p.matches[0].neutral,true);
assert.equal(project(state([row(0)])).matches[0].neutral,null,'Une absence de preuve du lieu ne devient pas un domicile attesté.');
console.log('Analyses : fenêtre, orientation, couverture, pondération, départage, saison et immuabilité PASS.');
// A real worker season verifies the data contract, not just handcrafted rows.
const {createBridge}=require('../native/engine/worker.cjs'),os=require('node:os');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-performance-')),bridge=createBridge({dataDir:root,seed:827381,now:1700000000000});let serial=0;
const good=(command,payload={})=>{const result=bridge.handle({id:++serial,command,payload});assert.equal(result.ok,true,command+': '+result.error);return result.model;};
try{
 good('new_career',{mode:'fiction',club:0});
 for(let i=0;i<5;i++){good('begin_match');good('delegate');good('finish_round');}
 const text=good('export').meta.exportText,saved=JSON.parse(text).state,disk=path.join(root,'PrototypeGodot','donnees.json'),bytes=fs.readFileSync(disk);
 const real=project(saved);assert.equal(real.summary.played,5);assert.equal(real.metrics.lineouts.matches,5);assert.equal(real.metrics.penalties.matches,5);
 const own=saved.history.filter(r=>r.pair.includes(saved.club)).slice(-5);
 assert.equal(real.summary.pointsFor,own.reduce((n,r)=>n+r.score[r.pair.indexOf(saved.club)],0));
 const resumed=project(JSON.parse(JSON.stringify(saved)));assert.deepEqual(resumed,real);
 assert.equal(good('export').meta.exportText,text);assert.deepEqual(fs.readFileSync(disk),bytes);
 const fixture=process.env.CD_PERFORMANCE_MODEL||path.join(root,'model.json');fs.writeFileSync(fixture,JSON.stringify({clubLife:{performanceAnalysis:real}}));
 const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
 if(godot){
  const run=require('node:child_process').spawnSync(godot,['--headless','--path',path.resolve(__dirname,'../native/godot'),'--script',path.join(__dirname,'performance-analysis-ui.gd')],{encoding:'utf8',timeout:60000,env:{...process.env,CD_PERFORMANCE_MODEL:fixture}});
  const log=(run.stdout||'')+(run.stderr||'');console.log(log);if(run.error)throw run.error;assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 }
 console.log('Analyses : cinq rencontres vrai worker, scores/stats, reprise JSON et état/RNG/disque inchangés PASS.');
}finally{bridge.close();}
