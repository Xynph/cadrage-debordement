'use strict';
const assert=require('node:assert/strict'),{context}=require('./monde-harness.cjs');
const aptitude=require('../native/engine/position-aptitudes.cjs'),quota=require('../native/engine/japan-quota-runtime.cjs').factory,eligibility=require('../native/engine/japan-eligibility.cjs').factory;
// Carrière Monde réelle d'un club de League One (68) : quota japonais et aptitudes du moteur, catégories de
// l'édition remplacées pour ce club par une inscription contrôlée.
const h=context(827381,{club:68});
h.run(`const qaTeam=club(),qaCategories=CDWorldCareer.edition(S).registry.japanCategories;qaTeam.players.forEach(p=>qaCategories[p.id]={category:'A-1',basis:'official-2026-27'});
for(let i=0;i<3;i++){const p={...qaTeam.players.find(p=>p.fam===6),id:'aaa-registered-C-'+i};qaTeam.players.push(p);qaCategories[p.id]={category:'C',basis:'estimated'};}
const qaStrongest={...qaTeam.players.find(p=>p.pos===POS[0]),id:'zzz-unregistered-prop',rating:99,skillBase:99,skills:Object.fromEntries(Object.keys(ATTR).map(k=>[k,99]))};qaTeam.players.push(qaStrongest);qaCategories[qaStrongest.id]={category:'C',basis:'estimated'};
var built=buildSheet(qaTeam);var managed=managerSheet(qaTeam,S.clubs[1],'Sec','classique');`);
assert.equal(h.run('CDWorldJapanQuota.registrationIds(S,qaTeam).has(qaStrongest.id)'),false);
for(const kind of ['built','managed']){
 assert.equal(h.run(`${kind}.lineup.concat(${kind}.bench).every(Boolean)`),true,kind+' retains all six registered front rows');
 assert.equal(h.run(`new Set(${kind}.lineup.concat(${kind}.bench)).size`),23);
 assert.equal(h.run(`CDWorldJapanQuota.nominations(S,qaTeam,${kind}.lineup,${kind}.bench)`),true);
 assert.equal(h.run(`${kind}.lineup.concat(${kind}.bench).includes(qaStrongest.id)`),false);
}
console.log('Japan real quota hooks and stronger unregistered prop: 9 checks passed');
