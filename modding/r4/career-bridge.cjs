'use strict';
/* Adaptation des carrières à l'unique gestionnaire R5 injecté.
 * Pas de sauvegarde disque, pas de second registre, pas d'activation implicite. */
function insist(condition,message){if(!condition)throw new Error(message)}
function clone(value){return JSON.parse(JSON.stringify(value))}
function validateWorld(world){
 insist(world&&typeof world.select==='function'&&typeof world.reset==='function'&&
  typeof world.binding==='function'&&typeof world.prepareNewCareer==='function'&&
  typeof world.checkCareer==='function','Contrat d’univers R5 requis');
 return world;
}
function createCareer(world,ids,template,createNativeCareer){
 validateWorld(world);
 insist(Array.isArray(ids)&&typeof createNativeCareer==='function','Sélection ou création invalide');
 insist(template&&typeof template==='object'&&!Array.isArray(template),'Configuration invalide');
 const previous=world.active();
 try{
  const snapshot=world.select(ids);
  const prepared=world.prepareNewCareer(template);
  // Le moteur natif ne doit pas modifier la signature qui sert à la reprise.
  const expected=clone(prepared.modBinding);
  const result=createNativeCareer(clone(prepared),clone(snapshot));
  insist(result&&typeof result==='object'&&!Array.isArray(result),'Carrière native invalide');
  insist(result.modBinding&&JSON.stringify(result.modBinding)===JSON.stringify(expected),
   'Création native : signature des mods perdue ou altérée');
  return result;
 }catch(error){
  // Une création échouée ne doit jamais laisser un autre univers activé.
  world.select(previous);
  throw error;
 }
}
function planResume(world,save){
 validateWorld(world);
 insist(save&&typeof save==='object'&&!Array.isArray(save),'Sauvegarde invalide');
 const old=world.active();
 try{
  if(!Object.prototype.hasOwnProperty.call(save,'modBinding')){
   const base=world.reset();
   return {ok:true,legacy:true,world:clone(base),save:clone(save)};
  }
  const binding=save.modBinding;
  insist(binding&&binding.schema===1&&Array.isArray(binding.mods),'Liaison absente ou invalide');
  insist(binding.mods.every(x=>x&&typeof x.id==='string'&&typeof x.version==='string'),'Mod mal défini');
  const requested=binding.mods.map(x=>x.id);
  const snapshot=world.select(requested);
  const check=world.checkCareer(save);
  insist(check.ok,check.reason||'Mods incompatibles avec la sauvegarde');
  return {ok:true,legacy:false,world:clone(snapshot),save:clone(save)};
 }catch(error){
  world.select(old);
  return {ok:false,reason:error.message,legacy:false};
 }
}
module.exports={createCareer,planResume};
