'use strict';
const fs=require('node:fs');
const path=require('node:path');
const zlib=require('node:zlib');
const crypto=require('node:crypto');
const LIMIT={archive:64*1024*1024,entries:5000,total:256*1024*1024,entry:12*1024*1024,ratio:120};
function ensure(ok,msg){if(!ok)throw Error(msg)}
function safe(p){return typeof p==='string'&&p.length>0&&p.length<220&&!p.includes('\\')&&!p.includes('%')&&!p.includes(':')&&!p.startsWith('/')&&!p.includes('//')&&p.split('/').every(x=>x&&x!=='.'&&x!=='..'&&!x.startsWith('.'))&&/^[a-zA-Z0-9/_.-]+$/.test(p)}
function crc32(bytes){
 let crc=0xffffffff;
 for(const b of bytes){
  crc^=b;
  for(let k=0;k<8;k++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);
 }
 return (crc^0xffffffff)>>>0;
}
function readZip(buffer){
 ensure(Buffer.isBuffer(buffer)&&buffer.length<=LIMIT.archive,'Archive trop volumineuse');
 const tail=Math.max(0,buffer.length-65557);let end=-1;
 for(let i=buffer.length-22;i>=tail;i--)if(buffer.readUInt32LE(i)===0x06054b50){end=i;break}
 ensure(end>=0,'Fin ZIP introuvable');
 const count=buffer.readUInt16LE(end+10),size=buffer.readUInt32LE(end+12),start=buffer.readUInt32LE(end+16);
 ensure(count<=LIMIT.entries&&start+size<=end,'Annuaire ZIP invalide');
 ensure(buffer.readUInt16LE(end+8)===count&&buffer.readUInt16LE(end+4)===0&&buffer.readUInt16LE(end+6)===0,'Archive ZIP multi-disque refusée');
 let offset=start,total=0;const files=Object.create(null);
 for(let i=0;i<count;i++){
  ensure(offset+46<=start+size&&buffer.readUInt32LE(offset)===0x02014b50,'Entrée centrale invalide');
  const flags=buffer.readUInt16LE(offset+8),method=buffer.readUInt16LE(offset+10);
  const crc=buffer.readUInt32LE(offset+16),packed=buffer.readUInt32LE(offset+20),unpacked=buffer.readUInt32LE(offset+24);
  const nameSize=buffer.readUInt16LE(offset+28),extra=buffer.readUInt16LE(offset+30),comment=buffer.readUInt16LE(offset+32);
  const local=buffer.readUInt32LE(offset+42);
  const name=buffer.subarray(offset+46,offset+46+nameSize).toString('utf8');
  offset+=46+nameSize+extra+comment;
  ensure(!(flags&1)&&[0,8].includes(method),'Chiffrement ou compression non supportée');
  ensure(safe(name)&&!name.endsWith('/')&&!Object.hasOwn(files,name),'Nom ZIP invalide ou dupliqué : '+name);
  ensure(unpacked<=LIMIT.entry&&packed<=LIMIT.archive&&unpacked<=Math.max(1,packed)*LIMIT.ratio,'ZIP bomb ou fichier trop grand');
  total+=unpacked;ensure(total<=LIMIT.total,'ZIP trop volumineux décompressé');
  ensure(local+30<=buffer.length&&buffer.readUInt32LE(local)===0x04034b50,'En-tête local invalide');
  const localNameSize=buffer.readUInt16LE(local+26),localExtra=buffer.readUInt16LE(local+28),begin=local+30+localNameSize+localExtra;
  ensure(begin+packed<=start,'Données hors de l’archive');
  ensure(buffer.subarray(local+30,local+30+localNameSize).toString('utf8')===name,'Nom local différent');
  const source=buffer.subarray(begin,begin+packed);
  const content=method===0?Buffer.from(source):zlib.inflateRawSync(source,{maxOutputLength:unpacked+1});
  ensure(content.length===unpacked,'Taille décompressée incorrecte');
  ensure(crc32(content)===crc,'CRC32 ZIP incorrect : '+name);
  files[name]=content;
 }
 return files;
}
function checkPackage(files){
 ensure(files&&files['manifest.json'],'manifest.json manquant');
 const manifest=JSON.parse(files['manifest.json'].toString('utf8'));
 ensure(manifest.schema===1&&/^[a-z][a-z0-9-]{2,63}$/.test(manifest.id||'')&&/^\d+\.\d+\.\d+$/.test(manifest.version||''),'Version/identité du mod invalide');
 ensure(Array.isArray(manifest.data)&&Array.isArray(manifest.assets),'Manifest data/assets manquants');
 const expected=new Set(['manifest.json']);
 for(const d of manifest.data){ensure(d&&safe(d.path)&&d.path.endsWith('.json'),'Chemin de données invalide');expected.add(d.path)}
 for(const a of manifest.assets){ensure(a&&safe(a.path)&&/^[a-f0-9]{64}$/.test(a.sha256||'')&&Number.isInteger(a.bytes),'Image invalide');expected.add(a.path)}
 ensure(expected.size===1+manifest.data.length+manifest.assets.length,'Chemins dupliqués');
 for(const name of Object.keys(files))ensure(expected.has(name),'Fichier non déclaré '+name);
 for(const name of expected)ensure(files[name],'Fichier absent '+name);
 for(const d of manifest.data){const entities=JSON.parse(files[d.path].toString('utf8'));ensure(Array.isArray(entities),'Données non tabulaires '+d.path)}
 for(const a of manifest.assets){
  const bytes=files[a.path];ensure(bytes.length===a.bytes,'Taille image non conforme');
  ensure(crypto.createHash('sha256').update(bytes).digest('hex')===a.sha256,'SHA image invalide');
 }
 return manifest;
}
function store(root){
 const location=path.resolve(root);fs.mkdirSync(location,{recursive:true});
 function installed(){
  return fs.readdirSync(location,{withFileTypes:true}).filter(x=>x.isDirectory()&&/^[a-z][a-z0-9-]{2,63}--[0-9]+\.[0-9]+\.[0-9]+$/.test(x.name)).map(x=>x.name);
 }
 function install(archive){
  const files=readZip(archive),manifest=checkPackage(files);
  const final=path.join(location,manifest.id+'--'+manifest.version);
  ensure(!fs.existsSync(final),'Version déjà installée');
  const stage=fs.mkdtempSync(path.join(location,'.pending-'));
  try{
   for(const [name,bytes] of Object.entries(files)){
    const dest=path.join(stage,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});
   }
   fs.renameSync(stage,final);
  }catch(e){fs.rmSync(stage,{recursive:true,force:true});throw e}
  return {id:manifest.id,version:manifest.version,path:final};
 }
 function checkBinding(binding){
  if(!binding||binding.schema!==1||!Array.isArray(binding.mods))return {ok:false,reason:'Signature absente'};
  const missing=binding.mods.filter(m=>!m||!/^[a-z][a-z0-9-]{2,63}$/.test(m.id||'')||!/^[0-9]+\.[0-9]+\.[0-9]+$/.test(m.version||'')||!fs.existsSync(path.join(location,m.id+'--'+m.version,'manifest.json')));
  return {ok:missing.length===0,missing};
 }
 return {install,checkBinding,installed};
}
module.exports={readZip,checkPackage,store,safe};
