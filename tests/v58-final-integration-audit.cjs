'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const c=require('../dist/coach-contract-cycle.js'),n=require('../dist/coach-negotiations.js'),m=require('../dist/coach-career.js');
const reports=[];
function t(name,fn){fn();reports.push({name,status:'pass'});}
const start=()=>n.create('manager',50);
const offer=(s,id,club,season=1,salary=40,years=2)=>n.apply(s,{type:'offer',id,clubId:club,season,salary,years}).state;
t('cycle et expiration 15 saisons',()=>{let s=start();for(let season=1;season<=15;season++){s=c.transition(s,season);assert.equal(c.audit(s).active,0)}assert.equal(s.events.length,0)});
t('offres expirees deviennent definitives',()=>{let s=offer(start(),'a','A');s=c.transition(s,3);assert.throws(()=>c.sign(s,'a',3,100));assert.equal(s.offers[0].status,'expired')});
t('contre offre refusee non appliquee',()=>{let s=offer(start(),'a','A',1,20);s=c.negotiate(s,'a',95,3,1,50).state;assert.equal(s.offers[0].counter,null);s=c.sign(s,'a',1,50);assert.equal(s.contracts[0].salary,20)});
t('offres concurrentes exclusivite',()=>{let s=offer(offer(start(),'a','A'),'b','B');s=c.sign(s,'a',1,60);assert.equal(s.offers.find(x=>x.id==='b').status,'declined');assert.equal(c.audit(s).active,1)});
t('reprise deterministe avec evenements',()=>{const run=()=>{let s=start();for(let y=1;y<=15;y++){s=c.transition(s,y);if(y%3===1){s=offer(s,'o'+y,'C'+y,y);s=c.sign(s,'o'+y,y,60)}if(y%3===2&&c.audit(s).active)s=c.dismiss(s,y)}return s};assert.deepEqual(run(),run());assert.deepEqual(JSON.parse(JSON.stringify(run())),run())});
t('controle IA recrutement de coach sans doublon',()=>{const s={clubs:[{id:'A',budget:100,reputation:50,coachId:null},{id:'B',budget:100,reputation:55,coachId:null}],coaches:[m.profile({id:'p',salary:30,reputation:50}),m.profile({id:'q',salary:30,reputation:55})],events:[]};const r=m.aiTurn(s,1);assert.equal(r.events.length,2);assert.equal(new Set(r.events.map(x=>x.coachId)).size,2);assert.equal(s.events.length,0)});
const report={kind:'synthetic-final-audit-not-integrated-save',passed:reports.length,checks:reports,knownGaps:['contracts not linked to actual game cash ledger','no real save migration or manager UI','vacancy candidate competition not connected to roster'],source:'PR #62 baseline'};
if(process.env.CD_V58_FINAL_REPORT)fs.writeFileSync(process.env.CD_V58_FINAL_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V58 FINAL AUDIT PASS '+JSON.stringify(report));
