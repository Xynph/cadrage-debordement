'use strict';
/* R2 : infrastructure de mods facultatifs, sans accès disque ou réseau implicite. */
const TYPES=Object.freeze(['competitions','clubs','players','staff','academy','fixtures']);
const ASSETS=Object.freeze(['club-logo','competition-logo','player-photo','staff-photo','stadium-photo']);
const ID=/^[a-z][a-z0-9-]{2,63}$/;
const VERSION=/^[0-9]+\.[0-9]+\.[0-9]+$/;
const EXT=/\.(?:png|jpg|jpeg|webp)$/i;
const MAX_ASSETS=25000,MAX_BYTES=256*1024*1024;
function plain(x){return x!==null&&typeof x==='object'&&!Array.isArray(x)&&Object.getPrototypeOf(x)===Object.prototype}
function safePath(path){
 return typeof path==='string'&&path.length<=200&&!path.includes('\\')&&!path.includes('%')&&
 !path.startsWith('/')&&!path.includes('//')&&!path.split('/').some(x=>!x||x==='.'||x==='..'||x.startsWith('.'))&&
 /^[a-zA-Z0-9/_\-.]+$/.test(path)&&!path.includes(':');
}
function failIf(condition,message){if(condition)throw new Error(message)}
function normalizedManifest(m){
 failIf(!plain(m),'Manifeste : objet attendu');
 failIf(m.schema!==1,'Manifeste : schema 1 attendu');
 failIf(!ID.test(m.id||''),'Manifeste : identifiant incorrect');
 failIf(!VERSION.test(m.version||''),'Manifeste : version semver incorrecte');
 failIf(typeof m.title!=='string'||!m.title.trim()||m.title.length>120,'Manifeste : titre incorrect');
 failIf(!['dataset','visual','combined'].includes(m.kind),'Manifeste : type incorrect');
 failIf(m.baseGame!==undefined&&m.baseGame!==1,'Manifeste : version du jeu incompatible');
 failIf(!Array.isArray(m.data)||!Array.isArray(m.assets),'Manifeste : sections data/assets requises');
 failIf(m.data.length>20||m.assets.length>MAX_ASSETS,'Manifeste : limite des entrées dépassée');
 const names=new Set();
 const reserve=p=>{failIf(!safePath(p)||names.has(p),'Chemin dangereux ou dupliqué : '+p);names.add(p)};
 for(const entry of m.data){
  failIf(!plain(entry)||!TYPES.includes(entry.type)||!safePath(entry.path)||!entry.path.endsWith('.json'),'Entrée de données invalide');
  reserve(entry.path);
 }
 for(const item of m.assets){
  failIf(!plain(item)||!ASSETS.includes(item.type)||!EXT.test(item.path||'')||
   !ID.test(item.ownerId||'')&&!/^(club|competition|player|staff|academy):[a-z0-9-]+$/.test(item.ownerId||''),
   'Ressource visuelle invalide');
  reserve(item.path);
  failIf(!Number.isInteger(item.bytes)||item.bytes<0||item.bytes>10*1024*1024,'Taille d’image invalide');
  failIf(typeof item.sha256!=='string'||!/^[a-f0-9]{64}$/.test(item.sha256),'SHA-256 requis pour chaque image');
 }
 failIf(m.assets.reduce((n,x)=>n+x.bytes,0)>MAX_BYTES,'Paquet visuel trop volumineux');
 if(m.dependencies!==undefined){
  failIf(!Array.isArray(m.dependencies)||m.dependencies.length>20,'Dépendances invalides');
  for(const dep of m.dependencies)failIf(!plain(dep)||!ID.test(dep.id||'')||!VERSION.test(dep.version||'')||dep.id===m.id,'Dépendance invalide');
 }
 if(m.conflicts!==undefined){
  failIf(!Array.isArray(m.conflicts)||m.conflicts.some(x=>!ID.test(x)),'Conflits invalides');
 }
 if(m.license!==undefined)failIf(typeof m.license!=='string'||!m.license.trim(),'Licence invalide');
 return JSON.parse(JSON.stringify(m));
}
function validateData(manifest,files){
 const errors=[],data={};
 for(const def of manifest.data){
  const value=files[def.path];
  if(!Array.isArray(value)){errors.push('Tableau absent : '+def.path);continue}
  if(value.length>30000){errors.push('Trop de lignes : '+def.path);continue}
  const seen=new Set();
  for(const [index,item] of value.entries()){
   if(!plain(item)||typeof item.id!=='string'||item.id.length>100||seen.has(item.id)){errors.push('ID invalide ou doublon '+def.path+' #'+index);continue}
   seen.add(item.id);
   if(typeof item.name!=='string'||!item.name.trim())errors.push('Nom absent '+def.path+' #'+index);
  }
  data[def.type]=(data[def.type]||[]).concat(value);
 }
 return {valid:errors.length===0,errors,data};
}
function preparePackage(input){
 failIf(!plain(input)||!plain(input.files),'Paquet attendu avec fichiers JSON explicites');
 const manifest=normalizedManifest(input.manifest);
 const expected=new Set(manifest.data.map(x=>x.path));
 for(const key of Object.keys(input.files))failIf(!expected.has(key),'Fichier JSON non déclaré : '+key);
 const checked=validateData(manifest,input.files);
 failIf(!checked.valid,checked.errors.join('\n'));
 return Object.freeze({manifest,records:checked.data,assets:manifest.assets.slice()});
}
function createRegistry(baseRecords={}){
 const installed=new Map(),state={active:[],base:JSON.parse(JSON.stringify(baseRecords))};
 const byId=()=>state.active.map(id=>installed.get(id));
 function install(pkg){
  const prepared=preparePackage(pkg);
  const m=prepared.manifest;
  failIf(installed.has(m.id),'Mod déjà installé : '+m.id);
  installed.set(m.id,prepared);
  return m.id;
 }
 function activate(ids){
  failIf(!Array.isArray(ids)||new Set(ids).size!==ids.length,'Activation dupliquée');
  for(const id of ids)failIf(!installed.has(id),'Mod absent : '+id);
  for(const id of ids){
   const m=installed.get(id).manifest;
   for(const d of m.dependencies||[])failIf(!ids.includes(d.id)||installed.get(d.id).manifest.version!==d.version,'Dépendance manquante : '+d.id);
   for(const c of m.conflicts||[])failIf(ids.includes(c),'Mods incompatibles : '+id+' / '+c);
  }
  const occupied=new Set(),merged=JSON.parse(JSON.stringify(state.base));
  for(const mod of ids.map(x=>installed.get(x))){
   for(const [kind,records] of Object.entries(mod.records)){
    merged[kind]=merged[kind]||[];
    const existing=new Set(merged[kind].map(x=>x.id));
    for(const item of records){
     failIf(existing.has(item.id)||occupied.has(kind+':'+item.id),'Conflit entité : '+kind+' '+item.id);
     occupied.add(kind+':'+item.id);existing.add(item.id);merged[kind].push(JSON.parse(JSON.stringify(item)));
    }
   }
  }
  state.active=ids.slice();
  return merged;
 }
 function disable(){state.active=[];return JSON.parse(JSON.stringify(state.base))}
 function saveBinding(){return {schema:1,mods:byId().map(p=>({id:p.manifest.id,version:p.manifest.version}))}}
 function checkSave(binding){
  if(!binding||binding.schema!==1||!Array.isArray(binding.mods))return {ok:false,reason:'Informations des mods manquantes'};
  const expected=saveBinding();
  return {ok:JSON.stringify(expected.mods)===JSON.stringify(binding.mods),reason:'Versions ou ordre des mods différents'};
 }
 return Object.freeze({install,activate,disable,saveBinding,checkSave,installed:()=>[...installed.keys()],active:()=>state.active.slice()});
}
module.exports={normalizedManifest,safePath,validateData,preparePackage,createRegistry};
