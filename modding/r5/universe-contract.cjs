'use strict';
/* Contrat commun R5, pur et sans mutation de S / anciennes sauvegardes. */
const ID=/^[a-z][a-z0-9-]{2,63}$/, VER=/^\d+\.\d+\.\d+$/;
const TYPES=['competitions','clubs','players','staff','academy','fixtures'];
function guard(ok,msg){if(!ok)throw new Error(msg)}
function copy(x){return JSON.parse(JSON.stringify(x))}
function validatePack(p){
 guard(p&&p.manifest&&p.records,'Paquet normalisé attendu');
 const m=p.manifest;
 guard(m.schema===1&&ID.test(m.id||'')&&VER.test(m.version||''),'Manifeste incompatible');
 guard(['dataset','visual','combined'].includes(m.kind),'Type incompatible');
 for(const key of Object.keys(p.records))guard(TYPES.includes(key)&&Array.isArray(p.records[key]),'Collection invalide '+key);
 const own=new Set();
 for(const [kind,rows] of Object.entries(p.records))for(const row of rows){
  guard(row&&typeof row.id==='string'&&row.id.length<=120&&typeof row.name==='string'&&row.name.trim(),'Entité invalide');
  guard(!own.has(kind+':'+row.id),'Entité dupliquée dans le mod');own.add(kind+':'+row.id)
 }
 return copy(p);
}
function createUniverse(base){
 const original=copy(base),installed=new Map();let selected=[];
 function install(p){const x=validatePack(p);guard(!installed.has(x.manifest.id),'Mod installé');installed.set(x.manifest.id,x);return x.manifest.id}
 function resolve(ids){
  guard(Array.isArray(ids)&&new Set(ids).size===ids.length,'Sélection en doublon');
  for(const id of ids)guard(installed.has(id),'Mod manquant : '+id);
  for(const id of ids){
   const m=installed.get(id).manifest;
   for(const dep of m.dependencies||[])guard(ids.includes(dep.id)&&installed.get(dep.id).manifest.version===dep.version,'Dépendance manquante '+dep.id);
   for(const conflict of m.conflicts||[])guard(!ids.includes(conflict),'Conflit '+conflict);
  }
  const world=copy(original);
  for(const id of ids){
   const pack=installed.get(id);
   for(const [type,rows] of Object.entries(pack.records)){
    world[type]=world[type]||[];
    const seen=new Set(world[type].map(x=>x.id));
    for(const row of rows){guard(!seen.has(row.id),'Conflit entité '+row.id);seen.add(row.id);world[type].push(copy(row))}
   }
  }
  // Enregistrer explicitement la sélection n'altère aucune carrière.
  return world;
 }
 function select(ids){const world=resolve(ids);selected=ids.slice();return world}
 function binding(){return {schema:1,mods:selected.map(id=>({id,version:installed.get(id).manifest.version}))}}
 function checkBinding(b){if(!b||b.schema!==1||!Array.isArray(b.mods))return {ok:false,reason:'Signature absente'};const actual=binding();const ok=JSON.stringify(actual.mods)===JSON.stringify(b.mods);return {ok,reason:ok?'OK':'Mods manquants, version ou ordre incompatibles'}}
 function prepareNewCareer(config={}){
  guard(config&&typeof config==='object'&&!Array.isArray(config),'Paramètres invalides');
  // On ajoute un champ uniquement à une nouvelle carrière, jamais aux anciennes.
  const output=copy(config);guard(!Object.prototype.hasOwnProperty.call(output,'modBinding'),'Liaison déjà présente');
  output.modBinding=binding();return output
 }
 function checkCareer(save){
  if(!save||typeof save!=='object')return {ok:false,reason:'Sauvegarde invalide'};
  if(!Object.prototype.hasOwnProperty.call(save,'modBinding'))return {ok:selected.length===0,legacy:true,reason:selected.length?'Ancienne carrière : désactiver les mods':'Ancienne carrière compatible sans conversion'};
  return {...checkBinding(save.modBinding),legacy:false}
 }
 return Object.freeze({install,select,reset:()=>select([]),binding,checkBinding,prepareNewCareer,checkCareer,available:()=>[...installed.keys()],active:()=>selected.slice(),snapshot:()=>resolve(selected)})
}
module.exports={validatePack,createUniverse};
