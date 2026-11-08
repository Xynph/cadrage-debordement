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
// A pure capacity projection on a copied state also reads an archived club
// office. The current manager and a duplicate historical reference must not
// change how many contractual seats the originating club has reserved.
const beforeReservations=h.state(),reservationSeed=h.seed();
h.run("const capacityCopy=JSON.parse(JSON.stringify(S));const loanPerson=capacityCopy.clubs[0].players.shift();capacityCopy.clubs[1].players.push(loanPerson);const loanOffice={loans:[{id:loanPerson.id,from:0,to:1,season:capacityCopy.season}]};capacityCopy.nativeAcademy={offices:{0:{v78to81:loanOffice}}};capacityCopy.club=2;");
assert.equal(h.run('professionalLoanReservations(capacityCopy.clubs[0],capacityCopy).length'),1,'Le bureau archivé conserve la place du club quitté.');
assert.equal(h.run('professionalPlaces(capacityCopy.clubs[0],capacityCopy)'),h.run('professionalPlaces()'),'Prêter ne libère aucune admission supplémentaire.');
h.run('capacityCopy.v78to81=loanOffice');
assert.equal(h.run('professionalLoanReservations(capacityCopy.clubs[0],capacityCopy).length'),1,'Une référence répétée ne réserve pas deux places.');
assert.deepEqual(h.state(),beforeReservations);assert.equal(h.seed(),reservationSeed,'Projection des réservations sans mutation ni RNG.');
console.log('Capacité : borne commune/historique, offre périmée, promotion, aperçu et plan de relève cohérents PASS.');
