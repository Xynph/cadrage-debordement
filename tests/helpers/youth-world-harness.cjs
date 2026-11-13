'use strict';
// Carrière mondiale complète (116 clubs, édition world-champ) dans la VM du moteur, sans bridge :
// sert aux tests des matchs des jeunes et à la mesure sur 20 saisons.
const {context}=require('../france-harness.cjs');
const systems=require('../../native/engine/native-systems.cjs');
const potentialEvolution=require('../../native/engine/potential-evolution.cjs');
const inSeasonDevelopment=require('../../native/engine/in-season-development.cjs');
const {extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry}=require('../../native/engine/world-pacific-registry.cjs');
function registries(){
 const base=require('../../native/engine/world-registry.json');
 const pacific=extendWorldRegistry(base,require('../../native/engine/world-pacific-extension.json'));
 const japan=extendJapanRegistry(pacific,require('../../native/engine/world-japan-extension.json'));
 const nationale=extendNationaleRegistry(japan,require('../../native/engine/world-nationale-extension.json'));
 const champ=extendChampRegistry(nationale,require('../../native/engine/world-champ-extension.json'));
 return {base,pacific,japan,nationale,champ};
}
function worldYouth({seed=827381,club=0}={}){
 const h=context(seed),r=registries();
 h.ctx.nativeWorldRegistryText=JSON.stringify(r.base);
 h.ctx.nativeWorldPacificRegistryText=JSON.stringify(r.pacific);
 h.ctx.nativeWorldJapanRegistryText=JSON.stringify(r.japan);
 h.ctx.nativeWorldNationaleRegistryText=JSON.stringify(r.nationale);
 h.ctx.nativeWorldChampRegistryText=JSON.stringify(r.champ);
 h.ctx.nativePotentialEvolutionValidate=potentialEvolution().validate;
 h.run(require('../../native/engine/world-vm.cjs').bootstrap());
 h.run(systems.bootstrap());
 h.run(`const nativeInSeasonDevelopment=(${inSeasonDevelopment.toString()})();nativeInSeasonDevelopment.installHooks();const nativePotentialEvolution=(${potentialEvolution.toString()})();nativePotentialEvolution.installHooks();`);
 h.run(`CDWorldCareer.start(${club},'world-champ');CDNativeAcademyGroups.start(S);`);
 return h;
}
module.exports={worldYouth};
