'use strict';
const path=require('node:path');

const SLOTS=Object.freeze(['city','stadium']);
const MAX_BYTES=2*1024*1024;
const MAX_EDGE=2400;
const MIN_WIDTH=320;
const MIN_HEIGHT=160;
const PHOTO_FILE=/^[a-f0-9]{64}\.(png|jpg|webp)$/;
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);

function ensure(ok,message){if(!ok)throw Error('Pack refusé : '+message);}
function only(value,allowed){
 ensure(object(value)&&Object.keys(value).length>0&&Object.keys(value).every(k=>allowed.includes(k)),'photo de territoire : champ inconnu.');
}
function credit(value){
 ensure(typeof value==='string'&&value.trim()&&value.length<=180&&!/[<>\x00-\x1f\x7f]/u.test(value),'photo de territoire : crédit manquant ou invalide.');
 return value.normalize('NFC').trim();
}
function https(value){
 ensure(typeof value==='string'&&value===value.trim()&&value.length<=512&&!/[\s<>\x00-\x1f\x7f]/u.test(value),'photo de territoire : adresse de source ou licence invalide.');
 let url;
 try{url=new URL(value);}catch{}
 ensure(url?.protocol==='https:'&&url.hostname&&!url.username&&!url.password,'photo de territoire : source ou licence HTTPS requise.');
 return value;
}
function attribution(row){return {credit:credit(row.credit),source:https(row.source),license:https(row.license)};}
function ingest(value,assets,referenced){
 only(value,SLOTS);const normalized={};
 for(const slot of SLOTS){
  if(!Object.hasOwn(value,slot))continue;
  const row=value[slot];only(row,['asset','credit','source','license']);
  const a=assets.get(row.asset);
  ensure(a&&a.bytes<=MAX_BYTES&&a.width>=MIN_WIDTH&&a.height>=MIN_HEIGHT&&Math.max(a.width,a.height)<=MAX_EDGE,'photo de territoire : fichier absent, cadrage trop petit ou taille excessive.');
  normalized[slot]={file:a.file,...attribution(row)};referenced.add(row.asset);
 }
 return normalized;
}
function validateInstalled(value){
 only(value,SLOTS);
 for(const slot of SLOTS){
  if(!Object.hasOwn(value,slot))continue;
  const row=value[slot];only(row,['file','credit','source','license']);
  ensure(typeof row.file==='string'&&PHOTO_FILE.test(row.file),'photo de territoire installée invalide.');
  attribution(row);
 }
}
function* files(value){
 for(const slot of SLOTS)if(value?.[slot]?.file)yield value[slot].file;
}
function project(value,folder){
 return Object.fromEntries(SLOTS.filter(slot=>value[slot]).map(slot=>{
  const {file,...text}=value[slot];return [slot,{...text,path:path.join(folder,file)}];
 }));
}
module.exports={ingest,validateInstalled,files,project};
