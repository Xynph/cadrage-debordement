'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const v65=require('../dist/staff-meeting-v65.js');
const advisor=require('../dist/staff-advisor-v66.js');
function state(){return {club:0,season:1,round:3,phase:'league',live:null,trained:false,
 morale:75,trust:72,economy:{week:3},manager:{inbox:[]},
 clubs:[{players:[{id:1,condition:52,injury:0},{id:2,condition:58,injury:0},
 {id:3,condition:64,injury:0},{id:4,condition:99,injury:2}]}]};}
function rootFor(s){let saves=0;const root={S:s,managerOffice(){return 'Bureau';},
 managerMessage(title,body,kind){s.manager.inbox.unshift({title,body,kind,season:s.season,week:s.economy.week})},
 save(){saves++},render(){}};v65.install(root);advisor.install(root,v65);
 return {root,saves:()=>saves};}
test('V66 : priorité récupération avec fatigue critique et blessés exclus',()=>{
 const s=state(),d=advisor.diagnostic(s,v65);
 assert.equal(d.recommended,'recuperation');
 assert.equal(d.players,3);assert.equal(d.fatigue,3);
 assert.equal(d.plans.find(x=>x.key==='recuperation').conditionGain,15);
 assert.equal(s.clubs[0].players[3].condition,99);
});
test('V66 : priorité moral puis confiance selon le diagnostic',()=>{
 const s=state();s.clubs[0].players.forEach(p=>p.condition=95);
 s.morale=55;s.trust=40;assert.equal(advisor.diagnostic(s,v65).recommended,'cohesion');
 s.morale=80;assert.equal(advisor.diagnostic(s,v65).recommended,'exigence');
 s.trust=85;assert.equal(advisor.diagnostic(s,v65).recommended,'cohesion');
});
test('V66 : projection non mutante et calcul chiffré cohérent',()=>{
 const s=state(),before=JSON.stringify(s),d=advisor.diagnostic(s,v65);
 assert.equal(JSON.stringify(s),before);
 assert.equal(d.plans.find(x=>x.key==='exigence').morale,73);
 assert.equal(d.plans.find(x=>x.key==='cohesion').morale,78);
});
test('V66 : un clic utilise V65, sauvegarde une fois et verrouille les deux écrans',()=>{
 const s=state(),x=rootFor(s);
 assert.equal(x.root.staffAdvisorV66('recuperation'),true);
 assert.equal(x.saves(),1);
 assert.equal(s.manager.inbox[0].kind,'staff-v65');
 assert.equal(x.root.staffAdvisorV66('recuperation'),false);
 assert.equal(x.root.staffAdvisorV66('exigence'),false);
 assert.equal(x.saves(),1);
 assert.match(x.root.managerOffice(),/LECTURE SEULE/);
});
test('V66 : hors match et choix invalide bloqués, installation idempotente',()=>{
 const s=state(),x=rootFor(s);
 assert.equal(advisor.install(x.root,v65),true);
 assert.equal((x.root.managerOffice().match(/Conseiller de staff · V66/g)||[]).length,1);
 assert.equal(x.root.staffAdvisorV66('unknown'),false);
 s.live={};assert.equal(x.root.staffAdvisorV66('cohesion'),false);
 assert.match(advisor.panel(s,v65),/disabled/);
 assert.equal(x.saves(),0);
});
test('V66 : valeurs échappées en HTML et conservation JSON',()=>{
 const s=state();s.morale='<script>';s.trust='&';
 const html=advisor.panel(s,v65);
 assert.doesNotMatch(html,/<script>/);assert.match(html,/&lt;script&gt;/);
 assert.match(html,/&amp;/);
 assert.equal(JSON.parse(JSON.stringify(s)).staffAdvisorV66,undefined);
});
