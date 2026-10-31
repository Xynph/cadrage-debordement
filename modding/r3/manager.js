'use strict';
/* Adaptateur R3 : aucun téléchargement réseau, aucune évaluation de code de mods. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.CDModManagerR3=api;
})(typeof globalThis==='object'?globalThis:this,function(){
 const MAX_IMAGE=10*1024*1024, MAX_JSON=4*1024*1024, MAX_FILES=20000;
 const IMAGE={'image/png':['png'],'image/jpeg':['jpg','jpeg'],'image/webp':['webp']};
 function assert(ok,msg){if(!ok)throw Error(msg)}
 function validPath(p){return typeof p==='string'&&p.length<200&&!p.includes('\\')&&!p.includes('%')&&!p.startsWith('/')&&!p.includes('//')&&!p.includes(':')&&p.split('/').every(x=>x&&x!=='.'&&x!=='..'&&!x.startsWith('.'))&&/^[a-zA-Z0-9/_\-.]+$/.test(p)}
 function validManifest(m){
  assert(m&&typeof m==='object'&&!Array.isArray(m),'Manifeste absent');
  assert(m.schema===1,'Version de manifeste inconnue');
  assert(/^[a-z][a-z0-9-]{2,63}$/.test(m.id||''),'Identifiant mod invalide');
  assert(/^\d+\.\d+\.\d+$/.test(m.version||''),'Version du mod invalide');
  assert(typeof m.title==='string'&&m.title.trim()&&m.title.length<=120,'Titre absent');
  assert(Array.isArray(m.data)&&Array.isArray(m.assets),'Inventaire du mod absent');
  assert(['dataset','visual','combined'].includes(m.kind),'Type du mod invalide');
  const paths=new Set();
  for(const d of m.data){assert(d&&validPath(d.path)&&d.path.endsWith('.json')&&!paths.has(d.path),'Chemin JSON dangereux ou dupliqué');paths.add(d.path)}
  for(const a of m.assets){assert(a&&validPath(a.path)&&!paths.has(a.path),'Chemin image dangereux ou dupliqué');paths.add(a.path);assert(/^[a-f0-9]{64}$/.test(a.sha256||''),'SHA-256 image absent');assert(Number.isInteger(a.bytes)&&a.bytes>=0&&a.bytes<=MAX_IMAGE,'Taille image invalide');assert(['club-logo','competition-logo','player-photo','staff-photo','stadium-photo'].includes(a.type),'Type image interdit')}
  assert(paths.size<=MAX_FILES,'Paquet trop volumineux');
  return m;
 }
 function basenameType(path){return (path.split('.').pop()||'').toLowerCase()}
 function mediaType(path){const ext=basenameType(path);return ext==='png'?'image/png':ext==='webp'?'image/webp':['jpg','jpeg'].includes(ext)?'image/jpeg':null}
 function checkSignature(bytes,mime){
  if(mime==='image/png')return bytes.length>=8&&[137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v);
  if(mime==='image/jpeg')return bytes.length>=4&&bytes[0]===255&&bytes[1]===216&&bytes[bytes.length-2]===255&&bytes[bytes.length-1]===217;
  if(mime==='image/webp')return bytes.length>=12&&[82,73,70,70].every((v,i)=>bytes[i]===v)&&[87,69,66,80].every((v,i)=>bytes[i+8]===v);
  return false;
 }
 async function digest(bytes,cryptoRef){
  const subtle=cryptoRef&&cryptoRef.subtle;
  assert(subtle&&typeof subtle.digest==='function','SHA-256 indisponible');
  return [...new Uint8Array(await subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
 }
 async function importMod(manifest,files,cryptoRef){
  validManifest(manifest);
  assert(files&&typeof files==='object','Fichiers absents');
  const expected=new Set([...manifest.data,...manifest.assets].map(x=>x.path));
  for(const path of Object.keys(files))assert(expected.has(path),'Fichier non déclaré : '+path);
  const data={};const images={};
  for(const d of manifest.data){
   const file=files[d.path];assert(file&&typeof file.arrayBuffer==='function','Fichier JSON absent : '+d.path);
   assert(file.size<=MAX_JSON,'Fichier JSON trop volumineux');
   const bytes=await file.arrayBuffer();
   assert(bytes.byteLength<=MAX_JSON,'JSON trop volumineux');
   const parsed=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
   assert(Array.isArray(parsed)&&parsed.length<=30000,'Tableau JSON attendu');
   for(const item of parsed)assert(item&&typeof item.id==='string'&&typeof item.name==='string','Entité invalide');
   data[d.type]=parsed;
  }
  for(const a of manifest.assets){
   const file=files[a.path];assert(file&&typeof file.arrayBuffer==='function','Image absente : '+a.path);
   assert(file.size===a.bytes&&file.size<=MAX_IMAGE,'Taille image incorrecte');
   const bytes=new Uint8Array(await file.arrayBuffer());
   const mime=mediaType(a.path);
   assert(mime&&checkSignature(bytes,mime),'Signature image invalide');
   assert((await digest(bytes,cryptoRef))===a.sha256,'Empreinte image incorrecte');
   images[a.path]={bytes,mime,ownerId:a.ownerId,type:a.type};
  }
  return {manifest:JSON.parse(JSON.stringify(manifest)),data,images};
 }
 function manager(base){
  const original=JSON.parse(JSON.stringify(base||{}));const installed=new Map();let active=null;
  return {
   install(pack){assert(pack&&pack.manifest,'Paquet absent');const id=pack.manifest.id;assert(!installed.has(id),'Mod déjà installé');installed.set(id,pack);return id},
   list(){return [...installed.values()].map(p=>({id:p.manifest.id,title:p.manifest.title,version:p.manifest.version,active:active===p.manifest.id}))},
   activate(id){assert(installed.has(id),'Mod non installé');active=id;return this.current()},
   deactivate(){active=null;return this.current()},
   current(){const result=JSON.parse(JSON.stringify(original));if(active){const p=installed.get(active);for(const [type,entries] of Object.entries(p.data)){result[type]=[...(result[type]||[]),...JSON.parse(JSON.stringify(entries))]}}return result},
   binding(){return {schema:1,mods:active?[{id:active,version:installed.get(active).manifest.version}]:[]}},
   compatible(binding){return !!binding&&binding.schema===1&&JSON.stringify(binding.mods)===JSON.stringify(this.binding().mods)}
  };
 }
 return {validPath,validManifest,checkSignature,digest,importMod,manager};
});
