'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const V65=require('../dist/staff-meeting-v65.js');
function state(){return {
 season:1,round:4,phase:'league',live:null,trained:false,morale:70,trust:70,club:0,
 economy:{week:4},manager:{inbox:[]},
 clubs:[{players:[{id:'a',name:'A',condition:73,injury:0},
 {id:'b',name:'B',condition:99,injury:0},
 {id:'c',name:'C',condition:20,injury:2}]}]
};}
function effects(s){let saves=0,renders=0;
 return {message(title,body,kind,action){s.manager.inbox.unshift({title,body,kind,action,season:s.season,week:s.economy.week})},
 save(){saves++;return true},render(){renders++},counters(){return {saves,renders}}};
}
test('V65 : récupération ciblée, blessés exclus et décisions persistées',()=>{
 const s=state(),calls=effects(s);
 assert.equal(V65.available(s),true);
 assert.equal(V65.perform(s,'recuperation',calls),true);
 assert.equal(s.clubs[0].players[0].condition,78);
 assert.equal(s.clubs[0].players[1].condition,99);
 assert.equal(s.clubs[0].players[2].condition,20);
 assert.equal(s.trust,69);
 assert.deepEqual(calls.counters(),{saves:1,renders:1});
 assert.equal(V65.available(s),false);
 assert.equal(V65.perform(s,'cohesion',calls),false);
 assert.equal(V65.currentMeeting(JSON.parse(JSON.stringify(s))).kind,'staff-v65');
});
test('V65 : cohésion et exigence ont des effets différents et bornés',()=>{
 const s=state();
 s.morale=97;s.trust=99;
 assert.equal(V65.perform(s,'cohesion',effects(s)),true);
 assert.equal(s.morale,98);
 assert.equal(s.clubs[0].players[0].condition,72);
 s.economy.week++;
 assert.equal(V65.perform(s,'exigence',effects(s)),true);
 assert.equal(s.morale,96);
 assert.equal(s.trust,100);
 assert.equal(s.clubs[0].players[0].condition,70);
});
test('V65 : interdiction pendant le match, après entraînement et hors ligue',()=>{
 for(const field of ['live','trained','phase']){
  const s=state();s[field]=field==='live'?{}:field==='trained'?true:'ended';
  assert.equal(V65.available(s),false);
  assert.equal(V65.perform(s,'cohesion',effects(s)),false);
 }
 const s=state();
 assert.equal(V65.perform(s,'inconnu',effects(s)),false);
 assert.equal(s.manager.inbox.length,0);
});
test('V65 : rollback des changements si sauvegarde impossible',()=>{
 const s=state(),snapshot=JSON.stringify(s);
 const fx=effects(s);fx.save=()=>false;
 assert.equal(V65.perform(s,'exigence',fx),false);
 assert.equal(JSON.stringify(s),snapshot);
});
test('V65 : le bureau affiche une décision effective et échappe les messages',()=>{
 const s=state();
 const out=V65.panel(s);
 assert.match(out,/staffMeetingV65\('recuperation'\)/);
 assert.match(out,/Réunion de staff/);
 s.manager.inbox.push({kind:'staff-v65',week:4,season:1,title:'<script>',body:'& rapport'});
 const done=V65.panel(s);
 assert.match(done,/&lt;script&gt;/);
 assert.match(done,/&amp; rapport/);
 assert.doesNotMatch(done,/onclick="staffMeetingV65/);
});
test('V65 : installation idempotente dans bureau et sans nouveau champ de sauvegarde',()=>{
 const s=state(),fx=effects(s);let saves=0;
 const root={S:s,managerOffice(){return '<div>Bureau</div>'},
 managerMessage:fx.message,save(){saves++},render(){}};
 assert.equal(V65.install(root),true);
 assert.equal(V65.install(root),true);
 assert.equal((root.managerOffice().match(/<h2>Réunion de staff/g)||[]).length,1);
 assert.equal(root.staffMeetingV65('cohesion'),true);
 assert.equal(saves,1);
 assert.equal(s.morale,73);
 assert.equal(root.staffMeetingV65('cohesion'),false);
 const copy=JSON.parse(JSON.stringify(s));
 assert.equal(copy.staffMeetingV65,undefined);
 assert.equal(copy.manager.inbox[0].kind,'staff-v65');
});
