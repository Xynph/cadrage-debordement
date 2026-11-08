'use strict';
const assert=require('node:assert/strict');
const {context}=require('./france-harness.cjs'),common=require('../native/engine/common-rosters.cjs');
function career(mode){const h=context();h.run('const CDCommonCareer=('+common.toString()+')();'+(mode==='common'?'CDCommonCareer.start(0)':'start(0)')+';validateCareer(S)');return h;}
for(const mode of ['common','historical']){
 const h=career(mode),limit=h.run('professionalCapacity()');assert.equal(limit,mode==='common'?Math.max(42,require('../dist/rugby-common-rosters.js').clubs[0].players.length+6):42);
 h.run("const candidate=S.market[0];if(!negotiateContract(candidate.id,'recruit',100000,1))throw Error('negotiate');");
 h.run('while(club().players.length<professionalCapacity()){if(!S.development.academy.length)throw Error("academy fixture exhausted");if(!promoteYouth(S.development.academy[0].id))throw Error("promotion fixture");}');
 const prior=h.state(),seed=h.seed();
 assert.equal(h.run("confirmContract(talkKey(candidate.id,'recruit'))"),false,'Une offre acceptée avant la dernière promotion est revérifiée avant signature ('+mode+').');
 assert.deepEqual(h.state(),prior);assert.equal(h.seed(),seed);
 assert.equal(h.run('promoteYouth(S.development.academy[0].id)'),false,'Aucune promotion au-delà de la capacité.');
 assert.equal(h.run("forecastQuote(S,{kind:'recruit',id:candidate.id,years:1}).valid"),false,'Aperçu et transaction refusent la même borne.');
 assert.equal(h.run("successionSimulate(S,[{kind:'youth',id:S.development.academy[0].id}],1).valid"),false,'Plan de relève respecte la borne.');
 h.run('validateCareer(S)');
}
const h=career('common');
assert.equal(h.run("successionSimulate(S,[{kind:'youth',id:S.development.academy[0].id}],1).valid"),true,'Le plan de relève accepte une promotion sous la capacité commune.');
console.log('Capacité : borne commune/historique, offre périmée, promotion, aperçu et plan de relève cohérents PASS.');
