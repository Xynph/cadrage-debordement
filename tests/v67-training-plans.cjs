'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const V67=require('../dist/training-plans-v67.js');
const outcome=(p,mode)=>{const old=p.physicalLoad?.fatigue||0;
 const fatigue=Math.max(0,Math.min(100,old+(mode==='repos'?-20:mode==='normal'?-10:6)));
 const base=mode==='repos'?30:mode==='normal'?20:8;
 return {fatigue,condition:Math.min(100,p.condition+Math.max(0,base-Math.min(10,Math.floor(fatigue/10))))};};
function state(){return {club:0,season:1,phase:'league',trained:false,live:null,training:'intense',
 lineup:['a','b'],clubs:[{players:[
 {id:'a',name:'Capitaine',age:30,condition:62,injury:0,physicalLoad:{version:1,fatigue:52,plan:'intense'}},
 {id:'b',name:'Jeune titulaire',age:21,condition:90,injury:0,physicalLoad:{version:1,fatigue:8,plan:'collective'}},
 {id:'c',name:'Espoir',age:20,condition:93,injury:0},
 {id:'d',name:'Blessé',age:22,condition:45,injury:2,physicalLoad:{version:1,fatigue:25,plan:'normal'}}
 ]}]};}
test('V67 : protection des titulaires, blessés exclus de l’intensité',()=>{
 const s=state(),p=V67.preview(s,'proteger',{outcome});
 assert.deepEqual(p.players.map(x=>x.plan),['repos','repos','normal','repos']);
 assert.equal(p.counts.intense,0);assert.equal(p.players[3].injured,true);
});
test('V67 : relève intensifiée sous conditions, titulaires fatigués protégés',()=>{
 const s=state(),p=V67.preview(s,'relever',{outcome});
 assert.deepEqual(p.players.map(x=>x.plan),['repos','intense','intense','repos']);
 s.clubs[0].players[2].physicalLoad={version:1,fatigue:40,plan:'normal'};
 assert.equal(V67.preview(s,'relever',{outcome}).players[2].plan,'normal');
});
test('V67 : le plan équilibré priorise la charge et la condition',()=>{
 const s=state(),p=V67.preview(s,'equilibrer',{outcome});
 assert.deepEqual(p.players.map(x=>x.plan),['repos','collective','collective','repos']);
 assert.equal(p.players[1].fatigue,0);
});
test('V67 : projection sans mutation ni nouveau champ de sauvegarde',()=>{
 const s=state(),before=JSON.stringify(s),p=V67.preview(s,'proteger',{outcome});
 assert.ok(p.conditionGain>0);assert.equal(JSON.stringify(s),before);
 assert.equal(JSON.parse(JSON.stringify(s)).trainingPlanV67,undefined);
});
test('V67 : application atomique et sauvegarde unique',()=>{
 const s=state();let saves=0,renders=0;
 assert.equal(V67.apply(s,'relever',{outcome,save(){saves++;return true},render(){renders++}}),true);
 assert.equal(saves,1);assert.equal(renders,1);assert.equal(s.training,'normal');
 assert.deepEqual(s.clubs[0].players.map(p=>p.physicalLoad.plan),['repos','intense','intense','repos']);
 assert.equal(s.clubs[0].players[2].physicalLoad.version,1);
});
test('V67 : rollback intégral sur échec de sauvegarde',()=>{
 const s=state(),before=JSON.stringify(s);
 assert.equal(V67.apply(s,'proteger',{outcome,save:()=>false}),false);
 assert.equal(JSON.stringify(s),before);
});
test('V67 : interdiction après séance, en match, hors ligue et clé inconnue',()=>{
 for(const field of ['trained','live','phase']){const s=state();
  s[field]=field==='trained'?true:field==='live'?{}:'ended';
  assert.equal(V67.apply(s,'proteger',{outcome,save:()=>true}),false);
 }
 assert.equal(V67.apply(state(),'inconnu',{outcome,save:()=>true}),false);
});
test('V67 : rendu protégé et boutons désactivés après entraînement',()=>{
 const s=state();s.clubs[0].players[0].name='<script>alert(1)</script>';s.trained=true;
 const html=V67.panel(s,{outcome});
 assert.match(html,/&lt;script&gt;/);assert.doesNotMatch(html,/<script>/);
 assert.match(html,/disabled/);
});
test('V67 : installation idempotente et intégration UI',()=>{
 const s=state();let saved=0;
 const root={S:s,tactics(){return 'Préparation';},physicalTrainingOutcome:outcome,
  save(){saved++},render(){}};
 assert.equal(V67.install(root),true);assert.equal(V67.install(root),true);
 assert.equal((root.tactics().match(/Plans d’entraînement · V67/g)||[]).length,1);
 assert.equal(root.trainingPlanV67('equilibrer'),true);assert.equal(saved,1);
});
