'use strict';
// Bridge R4 ZIP package to the single R5 world contract; no state or save mutation.
const fs=require('node:fs'),path=require('node:path');
const {readZip,checkPackage}=require('./package-store.cjs');
const KINDS=new Set(['competitions','clubs','players','staff','academy','fixtures']);
function requireOk(ok,msg){if(!ok)throw Error(msg)}
function toWorldPack(zipBytes){
 const files=readZip(zipBytes),manifest=checkPackage(files);
 requireOk(typeof manifest.title==='string'&&manifest.title.trim(),'Titre du mod obligatoire');
 requireOk(['dataset','visual','combined'].includes(manifest.kind),'Type de mod invalide');
 const result={};
 for(const item of manifest.data){
  requireOk(KINDS.has(item.type),'Collection interdite : '+item.type);
  const rows=JSON.parse(files[item.path].toString('utf8'));
  requireOk(Array.isArray(rows)&&rows.length<=30000,'Collection incorrecte : '+item.path);
  result[item.type] ||= [];
  result[item.type].push(...rows);
 }
 return {manifest,records:result};
}
function installIntoUniverse(zipBytes,world){
 requireOk(world&&typeof world.install==='function','Contrat d’univers R5 requis');
 const normalized=toWorldPack(zipBytes);
 // R5 becomes the sole source of truth; no activation here.
 return world.install(normalized);
}
function loadInstalled(root,id,version){
 requireOk(/^[a-z][a-z0-9-]{2,63}$/.test(id||'')&&/^\d+\.\d+\.\d+$/.test(version||''),'Identité du mod invalide');
 const directory=path.resolve(root,id+'--'+version);
 const manifestFile=path.join(directory,'manifest.json');
 requireOk(fs.statSync(manifestFile).isFile(),'Manifeste installé absent');
 const manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
 requireOk(manifest.id===id&&manifest.version===version,'Dossier et manifeste incohérents');
 const files=Object.create(null);files['manifest.json']=fs.readFileSync(manifestFile);
 for(const entry of [...manifest.data,...manifest.assets]){
  requireOk(typeof entry.path==='string'&&!entry.path.includes('..')&&!path.isAbsolute(entry.path)&&!entry.path.includes('\\'),'Chemin dangereux');
  const fullname=path.resolve(directory,entry.path);
  requireOk(fullname.startsWith(directory+path.sep),'Chemin hors mod');
  requireOk(fs.lstatSync(fullname).isFile(),'Fichier installé non ordinaire');
  files[entry.path]=fs.readFileSync(fullname);
 }
 checkPackage(files);
 const data={};
 for(const entry of manifest.data){data[entry.type] ||= [];data[entry.type].push(...JSON.parse(files[entry.path].toString('utf8')))}
 return {manifest,records:data};
}
module.exports={toWorldPack,installIntoUniverse,loadInstalled};
