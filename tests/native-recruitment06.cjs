'use strict';
const assert=require('node:assert/strict'),decisions=require('../native/engine/decisions.cjs');
const {context}=require('./france-harness.cjs'),h=context(10606);
h.run(`start(0,'fiction');const nativeDecisions=${decisions.toString()};`);
h.prepareNativeProjection();
// Explicit report fixture in the real native loader, not a claim of real scouting.
h.run(`{const p=managerPool()[0];S.manager.reports=[{id:'report-fixture',mission:'mission-fixture',playerId:p.id,name:'Émile D’Ávila',pos:p.pos,family:p.fam,age:p.age,note:72,potential:81,salary:p.salary,price:p.price,grade:'A',season:S.season,week:S.economy.week}];}`);
const project=()=>JSON.parse(h.run('JSON.stringify(nativeDecisions().recruitment)'));
const prior=h.run('JSON.stringify(S)'),seed=h.seed(),data=project(),report=data.reports[0];
assert.ok(report.assessment,'Carte de rapport argumentée');
assert.match(report.assessment.source,/Saison 1/);assert.ok(report.assessment.source.endsWith('suivi '+report.week));assert.equal(report.assessment.available,true);
assert.ok(report.assessment.observed.some(x=>x.includes('72')));assert.ok(report.assessment.estimates.some(x=>x.includes('81')));
assert.ok(report.assessment.limits.some(x=>/attributs|qualités/i.test(x)));assert.ok(report.assessment.fit.includes(report.pos)||/famille|besoin/i.test(report.assessment.fit));
for(let i=0;i<3;i++)assert.deepEqual(project(),data);assert.equal(h.run('JSON.stringify(S)'),prior);assert.equal(h.seed(),seed);
// Changing hidden/current player values cannot change what this dated report says.
h.run(`{const p=managerPool().find(p=>p.id===S.manager.reports[0].playerId);p.rating=99;p.dev.potential=99;p.skills={secret:99};}`);
assert.deepEqual(project().reports[0].assessment,report.assessment);
h.run('S.economy.week=20');const old=project().reports[0].assessment;assert.equal(old.stale,true);assert.match(old.caution,/ancien|actualiser/i);assert.equal(old.age,20-report.week);assert.ok(old.limits.some(x=>x.includes(String(20-report.week))));
h.run(`{const id=S.manager.reports[0].playerId;S.market=S.market.filter(p=>p.id!==id);S.economy.freeAgents=S.economy.freeAgents.filter(p=>p.id!==id);S.club=1;}`);
const gone=project().reports[0].assessment;assert.equal(gone.available,false);assert.match(gone.availability,/plus|absent|introuvable/i);assert.ok(!JSON.stringify(gone).includes('secret'));
// Defensive projection of a partial archive; strict import validation stays unchanged.
h.run(`S.manager.reports=[{id:'partial',playerId:'gone',name:'Zoé — ancien rapport',pos:'Pilier'}];`);
const partial=project().reports[0].assessment;assert.equal(partial.available,false);assert.match(partial.source,/non conservée/);assert.ok(partial.limits.some(x=>/niveau|note/i.test(x)));assert.ok(partial.estimates.some(x=>/inconnu|non conserv/i.test(x)));
assert.ok(!JSON.stringify(partial).includes('undefined'));assert.ok(!JSON.stringify(partial).includes('NaN'));
console.log('Recrutement06 : vrais besoins natifs, source datée, faits/estimations/inconnus, rapport ancien/partiel, candidat absent après mobilité, Unicode, aucun attribut caché/RNG/mutation PASS.');
