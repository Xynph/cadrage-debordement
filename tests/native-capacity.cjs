'use strict';
// Capacité professionnelle en carrière Monde (world-champ) : borne = effectif de référence de l'édition + 6
// (au moins 42, au plus 100), revérifiée à la signature, à la promotion, dans l'aperçu et le plan de relève.
const assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const h=context();
const reference=h.run('CDWorldCareer.edition(S).registry.clubs.find(c=>c.id===S.club).players.length');
const limit=h.run('professionalCapacity()');
assert.equal(limit,Math.min(100,Math.max(42,reference+6)),'Borne Monde : effectif de référence de l’édition + 6.');
assert.ok(h.run('club().players.length')<limit,'Places libres en début de carrière.');
assert.equal(h.run("successionSimulate(S,[{kind:'youth',id:S.development.academy[0].id}],1).valid"),true,'Le plan de relève accepte une promotion sous la capacité.');
// A pure capacity projection on a copied state also reads an archived club
// office. The current manager and a duplicate historical reference must not
// change how many contractual seats the originating club has reserved.
const beforeReservations=h.state(),reservationSeed=h.seed();
h.run("var capacityCopy=JSON.parse(JSON.stringify(S));var loanPerson=capacityCopy.clubs[S.club].players.shift();capacityCopy.clubs[1].players.push(loanPerson);var loanOffice={loans:[{id:loanPerson.id,from:S.club,to:1,season:capacityCopy.season}]};capacityCopy.nativeAcademy={offices:{[S.club]:{v78to81:loanOffice}}};capacityCopy.club=2;");
assert.equal(h.run('professionalLoanReservations(capacityCopy.clubs[S.club],capacityCopy).length'),1,'Le bureau archivé conserve la place du club quitté.');
assert.equal(h.run('professionalPlaces(capacityCopy.clubs[S.club],capacityCopy)'),h.run('professionalPlaces()'),'Prêter ne libère aucune admission supplémentaire.');
h.run('capacityCopy.v78to81=loanOffice');
assert.equal(h.run('professionalLoanReservations(capacityCopy.clubs[S.club],capacityCopy).length'),1,'Une référence répétée ne réserve pas deux places.');
assert.deepEqual(h.state(),beforeReservations);assert.equal(h.seed(),reservationSeed,'Projection des réservations sans mutation ni RNG.');
// Offre acceptée, puis l'effectif se remplit par promotions : la signature est revérifiée.
h.run("var candidate=S.market[0];if(!negotiateContract(candidate.id,'recruit',100000,1))throw Error('negotiate');");
h.run('while(club().players.length<professionalCapacity()){if(!S.development.academy.length)throw Error("academy fixture exhausted");if(!promoteYouth(S.development.academy[0].id))throw Error("promotion fixture");}');
const prior=h.state(),seed=h.seed();
assert.equal(h.run("confirmContract(talkKey(candidate.id,'recruit'))"),false,'Une offre acceptée avant la dernière promotion est revérifiée avant signature.');
assert.deepEqual(h.state(),prior);assert.equal(h.seed(),seed);
assert.equal(h.run('promoteYouth(S.development.academy[0].id)'),false,'Aucune promotion au-delà de la capacité.');
assert.equal(h.run("forecastQuote(S,{kind:'recruit',id:candidate.id,years:1}).valid"),false,'Aperçu et transaction refusent la même borne.');
assert.equal(h.run("successionSimulate(S,[{kind:'youth',id:S.development.academy[0].id}],1).valid"),false,'Plan de relève respecte la borne.');
h.run('validateCareer(S)');
h.close();
console.log('Capacité Monde : borne de l’édition, offre périmée, promotion, aperçu, plan de relève et prêts cohérents PASS.');
