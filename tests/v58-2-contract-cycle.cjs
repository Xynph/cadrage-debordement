'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),c=require('../dist/coach-contract-cycle.js'),n=require('../dist/coach-negotiations.js');let results=[];
function check(name,fn){fn();results.push(name);}
function seed(){return n.create('manager',50);}
function offer(s,id,club,season=1,salary=30,years=2){return n.apply(s,{type:'offer',id,clubId:club,season,salary,years}).state;}
check('expiration des offres en transition annuelle',()=>{let s=offer(seed(),'a','club-a');s=c.transition(s,3);assert.equal(s.offers[0].status,'expired');assert.equal(s.events.filter(e=>e.type==='offerExpired').length,1);});
check('transition idempotente',()=>{let s=offer(seed(),'a','club-a');const once=c.transition(s,3),twice=c.transition(once,3);assert.deepEqual(once,twice);});
check('expiration contrat au terme',()=>{let s=offer(seed(),'a','club-a');s=c.sign(s,'a',1,50);s=c.transition(s,3);assert.equal(s.contracts[0].status,'completed');assert.equal(s.history[0].reason,'contractEnd');});
check('contre proposition acceptee sous plafond',()=>{let s=offer(seed(),'a','club-a');const r=c.negotiate(s,'a',38,3,1,40);assert.equal(r.response.accepted,true);const signed=c.sign(r.state,'a',1,40);assert.equal(signed.contracts[0].salary,38);});
check('contre proposition refusee au dessus du plafond',()=>{let s=offer(seed(),'a','club-a');const r=c.negotiate(s,'a',58,3,1,40);assert.equal(r.response.accepted,false);assert.equal(r.state.offers[0].counter,null);});
check('signature offre expiree refusee',()=>{let s=offer(seed(),'a','club-a');assert.throws(()=>c.sign(s,'a',3,50));assert.equal(s.offers[0].status,'pending');});
check('licenciement sans emploi refuse',()=>assert.throws(()=>c.dismiss(seed(),1)));
check('demission et historique',()=>{let s=offer(seed(),'a','club-a');s=c.sign(s,'a',1,40);s=c.resign(s,2);assert.equal(s.history[0].reason,'resign');});
check('pas de double contrat actif',()=>{let s=offer(seed(),'a','club-a');s=c.sign(s,'a',1,40);s=offer(s,'b','club-b',2);s=c.sign(s,'b',2,40);assert.equal(c.audit(s).active,1);});
check('15 saisons deterministes et reprise JSON',()=>{const run=()=>{let s=seed();for(let y=1;y<=15;y++){s=c.transition(s,y);if(y%3===1){s=offer(s,'o'+y,'c'+y,y);s=c.sign(s,'o'+y,y,40);}if(y%3===2&&c.audit(s).active)s=c.resign(s,y);}return s;};assert.deepEqual(run(),run());assert.deepEqual(JSON.parse(JSON.stringify(run())),run());});
check('refus donnees contractuelles corrompues',()=>{let s=offer(seed(),'a','club-a');s=c.sign(s,'a',1,40);s.contracts[0].until=0;assert.throws(()=>c.audit(s));});
const report={kind:'independent-contract-fixtures-not-game-saves',passed:results.length,checks:results};
if(process.env.CD_V582_REPORT)fs.writeFileSync(process.env.CD_V582_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V58.2 CONTRACT CYCLE PASS '+JSON.stringify(report));
