'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs');
const V70=require('../dist/relations-duos-v70.js');
const {context}=require('./harness.cjs');
const p=(id,fam,score=65,condition=85,mental=70)=>({id,name:id,injury:0,fam,condition,skills:{mental},satisfaction:{score}});
function state(){
 return {version:2,club:0,season:1,phase:'league',round:4,trained:false,live:null,trust:75,
 economy:{week:4},manager:{serial:0,inbox:[]},clubs:[{players:[p('a',4,80,90,92),p('b',4,42,80),p('c',1,70,87)]}],lineup:['a','b','c']};
}
function fx(s){
 return {save(){return true},message(title,body,kind){s.manager.inbox.unshift({title,body,kind})},render(){}};
}
test('V70 : risque de rivalite argumente par satisfaction et meme poste, leader identifiable',()=>{
 const s=state();
 assert.equal(V70.leader(s).id,'a');
 assert.equal(V70.relation(s,'a','b').score,-15);
 assert.equal(V70.relation(s,'a','c').score,0);
 assert.equal(V70.relation(s,'a','a'),null);
 assert.match(V70.panel(s),/rivalités et leadership/);
});
test('V70 : mediation effective, verrou hebdomadaire, sauvegarde en JSON',()=>{
 const s=state();
 assert.equal(V70.perform(s,'mediation','a','b',fx(s)),true);
 assert.equal(V70.relation(s,'a','b').score,10);
 assert.equal(s.trust,74);
 assert.equal(s.manager.inbox.length,1);
 assert.equal(V70.perform(s,'duo','a','c',fx(s)),false);
 assert.equal(V70.allowed(JSON.parse(JSON.stringify(s))),false);
 s.economy.week++;
 assert.equal(V70.perform(s,'duo','a','c',fx(s)),true);
 assert.equal(V70.relation(s,'a','c').score,18);
 assert.equal(s.clubs[0].players[0].condition,88);
 assert.equal(s.clubs[0].players[2].condition,85);
});
test('V70 : mentorat reserve au leader, cout de charge, invalidations',()=>{
 const s=state();
 assert.equal(V70.preview(s,'mentorat','b','a'),null);
 assert.equal(V70.perform(s,'mentorat','a','c',fx(s)),true);
 assert.equal(s.clubs[0].players[0].condition,88);
 assert.equal(s.clubs[0].players[2].condition,87);
 assert.equal(V70.perform(s,'duo','a','a',fx(s)),false);
 s.economy.week++;
 s.live={};
 assert.equal(V70.allowed(s),false);
 s.live=null;s.trained=true;
 assert.equal(V70.allowed(s),false);
});
test('V70 : rollback exact en cas de sauvegarde impossible',()=>{
 const s=state(),before=JSON.stringify(s);
 assert.equal(V70.perform(s,'duo','a','b',{...fx(s),save:()=>false}),false);
 assert.equal(JSON.stringify(s),before);
});
test('V70 : incidence sur la feuille et le terrain, pas sur banc, plafonds, matchs historiques',()=>{
 const s=state();
 assert.equal(V70.perform(s,'duo','a','c',fx(s)),true);
 const l={userSide:0,pair:[0,1],sheets:[{initial:['a','b','c'],on:['a','b','c']}],finished:false};
 l.v70Relations=V70.matchSnapshot(s,l);
 assert.equal(l.v70Relations.duos.length,1);
 assert.ok(V70.matchBonus(l,0,'attack')>0);
 assert.equal(V70.matchBonus(l,1,'attack'),0);
 assert.equal(V70.matchBonus(l,0,'defence'),0);
 l.sheets[0].on=['a','b'];
 assert.equal(V70.matchBonus(l,0,'attack'),0);
 l.finished=true;
 assert.equal(V70.matchBonus(l,0,'attack'),0);
 assert.equal(V70.matchSnapshot(s,{...l,userSide:-1}),null);
});
test('V70 : installation idempotente et vraie incidence dans teamEdge',()=>{
 const s=state();V70.perform(s,'duo','a','c',fx(s));
 const root={S:s,managerTeamView(){return '<main>Equipe</main>'},createRugbyMatch(){return {userSide:0,pair:[0,1],sheets:[{initial:['a','b','c'],on:['a','b','c']}]}},teamEdge(){return .12},
 save(){},render(){},managerMessage(){},document:{getElementById:()=>({value:'a'})}};
 assert.equal(V70.install(root),true);
 assert.equal(V70.install(root),true);
 assert.equal((root.managerTeamView().match(/Relations de groupe V70/g)||[]).length,1);
 const match=root.createRugbyMatch([0,1]);
 assert.ok(root.teamEdge(match,0,'attack')>.12);
 assert.equal(root.teamEdge(match,0,'defence'),.12);
});
test('V70 : moteur natif, export/import et ancienne sauvegarde sans nouveau champ',()=>{
 const t=context();
 vm.runInContext(fs.readFileSync(__dirname+'/../dist/relations-duos-v70.js','utf8'),t.ctx);
 t.run('start(0)');
 assert.equal(t.run('typeof CDRelationsV70'), 'object');
 const before=t.run('createSaveDocument()');
 assert.equal(before.state.v70Relations,undefined);
 assert.equal(t.run('parseSaveDocument(JSON.stringify(createSaveDocument())).state.v70Relations'),undefined);
 const ids=t.run('[S.lineup[0],S.lineup[1]]');
 t.run('S.economy.week=2');
 t.run('S.v70Relations={version:1,last:"1:2",pairs:[{key:'+JSON.stringify(V70.pairKey?V70.pairKey(...ids):ids.slice().sort().join('|'))+',a:'+JSON.stringify(ids[0])+',b:'+JSON.stringify(ids[1])+',score:20,season:1,week:2}]}');
 const snapshot=t.run('createSaveDocument()');
 const checked=t.run('parseSaveDocument('+JSON.stringify(JSON.stringify(snapshot))+')');
 assert.equal(checked.state.v70Relations.pairs[0].score,20);
 const match=t.run('createRugbyMatch(nextMatch())');
 assert.equal(match.v70Relations?.version,1);
});
