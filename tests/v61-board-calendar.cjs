'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),m=require('../dist/board-calendar.js');
let passed=0;function t(name,f){f();passed++;console.log('PASS '+name)}
const add=(s,id,type,target,deadline)=>m.objective(s,{id,type,target,deadline});
t('creation et audit',()=>{const s=m.create('a');m.audit(s);assert.equal(s.trust,60)});
t('objectif unique et echeance valide',()=>{let s=add(m.create('a'),'w','wins',8,10);assert.throws(()=>add(s,'w','wins',8,11));assert.throws(()=>add(s,'z','wins',8,0))});
t('bilan victoire objectif atteint',()=>{let s=add(m.create('a'),'w','wins',8,10);let r=m.review(s,{week:10,metrics:{wins:9}});assert.equal(r.events[0].status,'met');assert.equal(r.state.trust,65)});
t('classement inversé',()=>{let s=add(m.create('a'),'r','rank',6,10);let r=m.review(s,{week:10,metrics:{rank:4}});assert.equal(r.events[0].status,'met')});
t('echec et confiance',()=>{let s=add(m.create('a'),'w','wins',8,10);let r=m.review(s,{week:10,metrics:{wins:2}});assert.equal(r.state.trust,52)});
t('metrique absente sans sanction',()=>{let s=add(m.create('a'),'c','cash',300,10);let r=m.review(s,{week:10,metrics:{}});assert.equal(r.events[0].status,'unverified');assert.equal(r.state.trust,60)});
t('bilan idempotent objectif',()=>{let s=add(m.create('a'),'w','wins',8,10);s=m.review(s,{week:10,metrics:{wins:2}}).state;s=m.review(s,{week:10,metrics:{wins:2}}).state;assert.equal(s.trust,52)});
t('briefing ordre echeance',()=>{let s=add(m.create('a'),'z','wins',8,12);s=add(s,'a','points',20,5);assert.deepEqual(m.briefing(s).upcoming.map(x=>x.id),['a','z'])});
t('transfert saison et preservation historique',()=>{let s=add(m.create('a'),'z','wins',8,10);s=m.review(s,{week:10,metrics:{wins:9}}).state;s=m.nextSeason(s);assert.equal(s.season,2);assert.equal(s.history.length,1);assert.equal(s.objectives.length,0)});
t('determinisme sur 15 saisons json',()=>{const run=()=>{let s=m.create('a');for(let year=1;year<=15;year++){s=add(s,'w'+year,'wins',7,10);s=m.review(s,{week:10,metrics:{wins:year%2?9:4}}).state;s=m.nextSeason(s)}return s};assert.deepEqual(run(),run());assert.deepEqual(JSON.parse(JSON.stringify(run())),run())});
t('rejet temporel et corruption',()=>{let s=add(m.create('a'),'w','wins',8,10);s=m.review(s,{week:10,metrics:{wins:7}}).state;assert.throws(()=>m.review(s,{week:9}));s.trust=101;assert.throws(()=>m.audit(s))});
const report={passed,scope:'independent synthetic board-calendar fixtures',limits:['not connected to existing V42 direction objectives','metrics require native results','no official save migration']};if(process.env.CD_V61_REPORT)fs.writeFileSync(process.env.CD_V61_REPORT,JSON.stringify(report,null,2)+'\n');console.log('V61 PASS '+JSON.stringify(report));
