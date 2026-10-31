'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {norm,distance,triage,loadRoster}=require('../tools/data06-triage.cjs');
test('fold accents, punctuation and common tiny spelling changes',()=>{
 assert.equal(norm('Peniami NARISIA'),norm('Péniami-Narisia'));
 assert.equal(distance('Adam HASTNGS','Adam HASTINGS'),1);
});
test('no automatic linking even with a perfect identity match',()=>{
 const results=triage([{name:'Peniami NARISIA',arrivalClub:'clermont',status:'not-found-in-roster',mappedId:null,autoImported:false,sourceUrl:'https://top14.lnr.fr/'}],[{id:'lnr:1',name:'Péniami-Narisia',club:'clermont'}]);
 assert.equal(results[0].candidates[0].id,'lnr:1');assert.equal(results[0].linkedId,null);assert.equal(results[0].autoImported,false);
 assert.equal(results[0].decision,'manual-review');
});
test('reject automatic mapping, bad data and duplicate stable IDs',()=>{
 assert.throws(()=>triage([{name:'A',arrivalClub:'b',mappedId:'lnr:1'}],[]),/Only unresolved/);
 assert.throws(()=>triage([{name:'A',arrivalClub:'b'}],[{id:'lnr:1'},{id:'lnr:1'}]),/Duplicate/);
});
test('real reference corpus is 1592 unique players',()=>{
 const roster=loadRoster(path.resolve(__dirname,'..'));
 assert.equal(roster.length,1592);assert.equal(new Set(roster.map(p=>p.id)).size,1592);
});
