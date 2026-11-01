'use strict';
// Entrée isolée pour le choix d'univers d'une NOUVELLE carrière.
// Aucune connexion automatique à l'interface existante, aux sauvegardes ou au moteur.
const {createCareer}=require('../r4/career-bridge.cjs');
const {installRugbyRealBirthyears}=require('./r5-birthyears-pack.cjs');
const ID='rugby-real-birthyears-2026';
const OPTIONS=Object.freeze([
  Object.freeze({id:'fictional',label:'Univers fictif (défaut)',mods:[]}),
  Object.freeze({id:'rugby-real-2026',label:'Rugby Réel 2026-2027 (données de naissance)',mods:[ID]})
]);
function choices(){return OPTIONS.map(x=>({...x,mods:x.mods.slice()}));}
function ensureAvailable(world){
  if(!world||typeof world.available!=='function'||typeof world.install!=='function')throw Error('Univers R5 requis');
  if(!world.available().includes(ID))installRugbyRealBirthyears(world);
}
function startNewCareer(world,universeId,template,createNativeCareer){
  if(!OPTIONS.some(x=>x.id===universeId))throw Error('Choix d univers invalide');
  if(!template||typeof template!=='object'||Array.isArray(template))throw Error('Configuration invalide');
  if(typeof createNativeCareer!=='function')throw Error('Créateur natif requis');
  if(template.startDate && template.startDate!=='2026-07-01')throw Error('Date départ 2026-07-01 obligatoire');
  if(template.modBinding)throw Error('Liaison de sauvegarde fournie : nouvelle carrière seulement');
  const selected=OPTIONS.find(x=>x.id===universeId).mods;
  if(selected.length)ensureAvailable(world);
  return createCareer(world,selected,{...template,season:'2026-2027',startDate:'2026-07-01'},createNativeCareer);
}
module.exports={choices,startNewCareer};
