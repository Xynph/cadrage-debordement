'use strict';
// Identity data is parsed outside the simulation VM. Only normalized data and
// hash-named images are installed; archive paths never become output paths.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto');
const MiB=1024*1024,LIMITS=Object.freeze({archive:512*MiB,total:768*MiB,entries:5000,image:16*MiB,manifest:4*MiB,pixels:40000000});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function check(ok,message){if(!ok)throw Error('Pack refusé : '+message);}
function object(v){return v!==null&&typeof v==='object'&&!Array.isArray(v);}
function keys(v,allowed){check(object(v)&&Object.keys(v).every(k=>allowed.includes(k)),'champ non autorisé.');}
function name(v){check(typeof v==='string'&&v.trim().length>0&&v.length<=120&&!/[<>\x00-\x1f\x7f]/.test(v),'nom invalide.');return v.normalize('NFC');}
function abbreviation(v){check(typeof v==='string'&&/^[\p{L}\p{N}]{1,8}$/u.test(v),'abréviation invalide.');return v.normalize('NFC');}
function deriveAbbreviation(title){return abbreviation(title.split(/[\s’'\-]+/u).filter(w=>w&&!['de','du','des','la','le','les','et'].includes(w.toLowerCase())).map(w=>/^[A-Z0-9]{1,4}$/.test(w)?w:[...w][0].toUpperCase()).join('').slice(0,8));}
function zipPath(raw){check(typeof raw==='string'&&raw.length>0&&raw.length<=600&&!/[\\:\x00-\x1f\x7f]/.test(raw)&&!raw.startsWith('/'),'chemin ZIP interdit.');const n=raw.normalize('NFC'),parts=n.replace(/\/$/,'').split('/');check(parts.every(p=>p&&p!=='.'&&p!=='..'&&!/[. ]$/.test(p)&&! /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)),'chemin ZIP interdit.');return n;}
const crcTable=Array.from({length:256},(_,n)=>{for(let i=0;i<8;i++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function crc32(b){let c=0xffffffff;for(const v of b)c=crcTable[(c^v)&255]^(c>>>8);return (c^0xffffffff)>>>0;}
function utf8(b){return new TextDecoder('utf-8',{fatal:true}).decode(b);}
function extra(b){let p=0;while(p<b.length){check(p+4<=b.length,'extra ZIP tronqué.');const id=b.readUInt16LE(p),n=b.readUInt16LE(p+2);check(id!==1&&p+4+n<=b.length,'ZIP64 ou extra invalide.');p+=4+n;}}
function readZip(file){
 check(typeof file==='string'&&path.isAbsolute(file),'chemin absolu requis.');const fd=fs.openSync(file,'r');let b;
 try{const s=fs.fstatSync(fd);check(s.isFile()&&s.size<=LIMITS.archive&&s.size>=22,'taille archive invalide.');b=Buffer.alloc(s.size);let n=0;while(n<b.length){const got=fs.readSync(fd,b,n,b.length-n,n);check(got>0,'archive tronquée.');n+=got;}check(fs.fstatSync(fd).size===s.size,'archive modifiée.');}finally{fs.closeSync(fd);}
 let end=-1;for(let i=b.length-22;i>=Math.max(0,b.length-65557);i--)if(b.readUInt32LE(i)===0x06054b50&&i+22+b.readUInt16LE(i+20)===b.length){end=i;break;}
 check(end>=0,'fin ZIP absente.');check(b.readUInt16LE(end+4)===0&&b.readUInt16LE(end+6)===0,'ZIP multi-disque.');const count=b.readUInt16LE(end+10),size=b.readUInt32LE(end+12),offset=b.readUInt32LE(end+16);check(count===b.readUInt16LE(end+8)&&count>0&&count<=LIMITS.entries&&count!==65535&&offset+size===end,'annuaire ZIP invalide/ZIP64.');
 const entries=new Map(),folded=new Set(),ranges=[];let p=offset,total=0;
 for(let i=0;i<count;i++){
  check(p+46<=end&&b.readUInt32LE(p)===0x02014b50,'annuaire ZIP tronqué.');const flags=b.readUInt16LE(p+8),method=b.readUInt16LE(p+10),crc=b.readUInt32LE(p+16),compressed=b.readUInt32LE(p+20),length=b.readUInt32LE(p+24),nl=b.readUInt16LE(p+28),el=b.readUInt16LE(p+30),cl=b.readUInt16LE(p+32),start=b.readUInt32LE(p+42),mode=b.readUInt32LE(p+38)>>>16;
  check(p+46+nl+el+cl<=end&&b.readUInt16LE(p+34)===0,'entrée tronquée/multi-disque.');check((flags&~0x808)===0&&[0,8].includes(method),'chiffrement ou méthode ZIP interdite.');check((mode&0xf000)!==0xa000&&[0,0x8000,0x4000].includes(mode&0xf000),'lien ou fichier spécial interdit.');check(compressed!==0xffffffff&&length!==0xffffffff&&start!==0xffffffff,'ZIP64 interdit.');
  const raw=b.subarray(p+46,p+46+nl);check(flags&0x800||raw.every(v=>v<128),'nom ZIP non UTF-8.');const n=zipPath(utf8(raw)),fold=n.replace(/\/$/,'').toLowerCase();check(!folded.has(fold),'doublon de chemin Unicode/casse.');folded.add(fold);extra(b.subarray(p+46+nl,p+46+nl+el));
  const dir=n.endsWith('/');check(!dir||length===0,'répertoire non vide.');check(length<=LIMITS.image,'entrée trop volumineuse.');total+=length;check(total<=LIMITS.total,'décompression totale trop volumineuse.');
  check(start+30<=offset&&b.readUInt32LE(start)===0x04034b50,'en-tête local invalide.');const lnl=b.readUInt16LE(start+26),lel=b.readUInt16LE(start+28),data=start+30+lnl+lel;
  check(data+compressed<=offset&&b.readUInt16LE(start+6)===flags&&b.readUInt16LE(start+8)===method&&raw.equals(b.subarray(start+30,start+30+lnl)),'en-têtes ZIP incohérents.');extra(b.subarray(start+30+lnl,data));
  if(!(flags&8))check(b.readUInt32LE(start+14)===crc&&b.readUInt32LE(start+18)===compressed&&b.readUInt32LE(start+22)===length,'tailles ZIP incohérentes.');
  let finish=data+compressed;if(flags&8){let q=finish;if(q+4<=offset&&b.readUInt32LE(q)===0x08074b50)q+=4;check(q+12<=offset&&b.readUInt32LE(q)===crc&&b.readUInt32LE(q+4)===compressed&&b.readUInt32LE(q+8)===length,'descripteur ZIP invalide.');finish=q+12;}
  ranges.push([start,finish]);entries.set(n,{name:n,dir,length,read(max=LIMITS.image){check(length<=max,'fichier trop volumineux.');const input=b.subarray(data,data+compressed),out=method===0?input:zlib.inflateRawSync(input,{maxOutputLength:Math.max(1,length)});check(out.length===length&&crc32(out)===crc,'taille ou CRC invalide.');return out;}});p+=46+nl+el+cl;
 }
 check(p===end,'annuaire ZIP incohérent.');ranges.sort((a,b)=>a[0]-b[0]);let previous=0;for(const [start,finish]of ranges){check(start===previous,'chevauchement ou données ZIP non déclarées.');previous=finish;}check(previous===offset,'données ZIP non déclarées.');
 for(const n of entries.keys()){let parent=n.replace(/\/$/,'');while(parent.includes('/')){parent=parent.slice(0,parent.lastIndexOf('/'));check(!entries.has(parent),'fichier parent de répertoire.');}}
 return {digest:hash(b),entries};
}
function imageInfo(b){
 let width,height,ext;
 if(b.length>=33&&b.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))&&b.toString('ascii',12,16)==='IHDR'){width=b.readUInt32BE(16);height=b.readUInt32BE(20);ext='png';}
 else if(b.length>=12&&b[0]===255&&b[1]===216){let p=2;while(p+4<=b.length){check(b[p]===255,'JPEG invalide.');while(b[p]===255)p++;const marker=b[p++];if(marker===217||marker===218)break;if(marker===1||marker>=208&&marker<=215)continue;check(p+2<=b.length,'JPEG tronqué.');const len=b.readUInt16BE(p);check(len>=2&&p+len<=b.length,'JPEG tronqué.');if([192,193,194,195,197,198,199,201,202,203,205,206,207].includes(marker)){check(len>=8,'JPEG SOF invalide.');height=b.readUInt16BE(p+3);width=b.readUInt16BE(p+5);break;}p+=len;}ext='jpg';}
 else if(b.length>=30&&b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WEBP'&&b.readUInt32LE(4)+8===b.length){const kind=b.toString('ascii',12,16);if(kind==='VP8X'){check(!(b[20]&2),'WebP animé interdit.');width=b.readUIntLE(24,3)+1;height=b.readUIntLE(27,3)+1;}else if(kind==='VP8 '&&b[23]===157&&b[24]===1&&b[25]===42){width=b.readUInt16LE(26)&16383;height=b.readUInt16LE(28)&16383;}else if(kind==='VP8L'&&b[20]===47){const bits=b.readUInt32LE(21);width=(bits&16383)+1;height=((bits>>>14)&16383)+1;}ext='webp';}
 check(Number.isInteger(width)&&Number.isInteger(height)&&width>0&&height>0&&width*height<=LIMITS.pixels,'image invalide ou dimensions excessives.');return {width,height,ext};
}
function textEntity(s){return s.replace(/&(#x[0-9a-f]+|#\d+|amp|quot|apos|lt|gt|nbsp);/gi,(_,e)=>{if(e[0]==='#'){const n=e[1].toLowerCase()==='x'?parseInt(e.slice(2),16):Number(e.slice(1));check(n>0&&n<=0x10ffff,'entité invalide.');return String.fromCodePoint(n);}return {amp:'&',quot:'"',apos:"'",lt:'<',gt:'>',nbsp:' '}[e.toLowerCase()];});}
function analyse(file,database){
 const zip=readZip(file),{entries}=zip;let manifest,root='',custom=entries.has('pack.json');const readJson=n=>{const e=entries.get(n);check(e&&!e.dir,'manifeste absent.');return JSON.parse(utf8(e.read(LIMITS.manifest)));};
 if(custom)manifest=readJson('pack.json');else{const found=[...entries.keys()].filter(n=>n.endsWith('/inventaire.json')||n==='inventaire.json');check(found.length===1,'un seul manifeste requis.');root=found[0].slice(0,-'inventaire.json'.length);const source=readJson(found[0]);check(source.schema==='rugby-real-unified-pack-v2'&&Array.isArray(source.entries),'format non pris en charge.');manifest={schema:'cd-identity-pack-v1',id:'rugby-reel',name:name(source.packName),version:name(source.season),databaseId:database.id,rightsStatus:'not-cleared-for-public-distribution',clubs:[],players:[],assets:[]};
  for(const entry of source.entries){check(object(entry)&&['logo','portrait'].includes(entry.kind)&&(entry.kind==='logo'||typeof entry.synthetic==='boolean')&&['downloaded','generated-ai'].includes(entry.status),'inventaire invalide.');const aid='asset-'+manifest.assets.length;manifest.assets.push({id:aid,path:root+entry.path,sha256:entry.sha256,bytes:entry.bytes});if(entry.kind==='logo'){const club=database.clubs.find(c=>c.slug===entry.id);check(club,'club inconnu.');const gallery=entries.get(root+'Photos/'+entry.id+'/index.html');check(gallery,'titre de club absent.');const title=/<title>([^<]{1,500})<\/title>/i.exec(utf8(gallery.read(LIMITS.manifest)));check(title,'titre de club invalide.');manifest.clubs.push({id:club.id,name:name(textEntity(title[1])),abbr:deriveAbbreviation(textEntity(title[1])),logo:aid});}else manifest.players.push({id:entry.id,name:name(entry.name),portrait:aid,synthetic:entry.synthetic});}
 }
 keys(manifest,['schema','id','name','version','databaseId','rightsStatus','clubs','players','assets']);check(manifest.schema==='cd-identity-pack-v1'&&manifest.databaseId===database.id,'base de données incompatible.');check(typeof manifest.id==='string'&&/^[a-z0-9][a-z0-9-]{0,39}$/.test(manifest.id),'identifiant de pack invalide.');manifest.name=name(manifest.name);manifest.version=name(manifest.version);manifest.rightsStatus=name(manifest.rightsStatus);check(Array.isArray(manifest.clubs)&&manifest.clubs.length<=30&&Array.isArray(manifest.players)&&manifest.players.length<=database.playerCount&&Array.isArray(manifest.assets)&&manifest.assets.length<=1622,'listes invalides.');
 const players=new Set(database.clubs.flatMap(c=>c.players.map(p=>p.id))),clubs=new Set(database.clubs.map(c=>c.id)),assetMap=new Map(),used=new Set(),files=new Map();
 for(const a of manifest.assets){keys(a,['id','path','sha256','bytes']);check(typeof a.id==='string'&&/^[a-zA-Z0-9_-]{1,80}$/.test(a.id)&&!assetMap.has(a.id),'identifiant de média invalide/dupliqué.');check(typeof a.sha256==='string'&&/^[0-9a-f]{64}$/.test(a.sha256)&&Number.isSafeInteger(a.bytes)&&a.bytes>0&&a.bytes<=LIMITS.image,'empreinte/taille média invalide.');a.path=zipPath(a.path);check(!used.has(a.path),'média déclaré plusieurs fois.');used.add(a.path);const e=entries.get(a.path);check(e&&!e.dir&&e.length===a.bytes,'média absent/taille incorrecte.');const data=e.read(),info=imageInfo(data);check(hash(data)===a.sha256,'empreinte SHA256 incorrecte.');const filename=a.sha256+'.'+info.ext;assetMap.set(a.id,filename);files.set(filename,data);}
 const mappedClubs={},mappedPlayers={};let logos=0,official=0,synthetic=0;const referenced=new Set();
 for(const c of manifest.clubs){keys(c,['id','name','abbr','logo']);check(clubs.has(c.id)&&!mappedClubs[c.id],'club inconnu/dupliqué.');check(c.name!==undefined||c.abbr!==undefined||c.logo!==undefined,'identité vide.');const out={};if(c.name!==undefined)out.name=name(c.name);if(c.abbr!==undefined)out.abbr=abbreviation(c.abbr);if(c.logo!==undefined){check(assetMap.has(c.logo),'logo inconnu.');out.logo=assetMap.get(c.logo);referenced.add(c.logo);logos++;}mappedClubs[c.id]=out;}
 for(const p of manifest.players){keys(p,['id','name','portrait','synthetic']);check(players.has(p.id)&&!mappedPlayers[p.id],'joueur inconnu/dupliqué.');check(p.name!==undefined||p.portrait!==undefined,'identité vide.');const out={};if(p.name!==undefined)out.name=name(p.name);if(p.portrait!==undefined){check(assetMap.has(p.portrait)&&typeof p.synthetic==='boolean','portrait ou mention synthétique invalide.');out.portrait=assetMap.get(p.portrait);out.portraitStatus=p.synthetic?'synthetic':'official';referenced.add(p.portrait);p.synthetic?synthetic++:official++;}else check(p.synthetic===undefined,'mention synthétique sans portrait.');mappedPlayers[p.id]=out;}
 check(referenced.size===assetMap.size,'média sans identité.');
 for(const e of entries.values()){if(e.dir||used.has(e.name))continue;check(/\.(json|csv|txt|html)$/i.test(e.name),'fichier supplémentaire interdit : '+e.name);e.read(LIMITS.manifest);}
 const meta={id:manifest.id+'-'+zip.digest,name:manifest.name,version:manifest.version,digest:zip.digest,databaseId:manifest.databaseId,counts:{clubs:manifest.clubs.length,players:manifest.players.length,logos,official,synthetic},rightsStatus:manifest.rightsStatus};
 return {meta,clubs:mappedClubs,players:mappedPlayers,files};
}
function createStore(dataDir,database){
 const physical=fs.realpathSync.native(dataDir),root=path.join(physical,'packs');let preview=null,storageWarning=null;const cache=new Map();
 function confined(target){let p=path.resolve(target);while(!fs.existsSync(p))p=path.dirname(p);const real=fs.realpathSync.native(p),rel=path.relative(physical,real);check(rel===''||!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel),'stockage hors du profil physique.');let ancestor=p;while(ancestor!==physical){check(!fs.lstatSync(ancestor).isSymbolicLink(),'lien de stockage interdit.');const parent=path.dirname(ancestor);if(parent===ancestor)break;ancestor=parent;}}
 function read(id){if(typeof id!=='string'||! /^[a-z0-9][a-z0-9-]{0,39}-[0-9a-f]{64}$/.test(id))return null;const folder=path.join(root,id),file=path.join(folder,'manifest.json');if(!fs.existsSync(file)){cache.delete(id);return null;}try{confined(file);const stat=fs.statSync(file);check(stat.isFile()&&stat.size<=LIMITS.manifest,'manifeste installé invalide.');const stamp=stat.mtimeMs+':'+stat.size+':'+fs.statSync(folder).mtimeMs;if(cache.get(id)?.stamp===stamp)return cache.get(id).pack;const pack=JSON.parse(fs.readFileSync(file,'utf8'));check(pack.meta.id===id&&pack.meta.digest===id.slice(-64)&&pack.meta.databaseId===database.id&&object(pack.clubs)&&object(pack.players),'pack installé invalide.');for(const group of [pack.clubs,pack.players])for(const item of Object.values(group)){const n=item.logo||item.portrait;if(n){check(/^[0-9a-f]{64}\.(png|jpg|webp)$/.test(n),'média installé invalide.');const asset=path.join(folder,n);confined(asset);check(fs.statSync(asset).isFile()&&hash(fs.readFileSync(asset))===n.slice(0,64),'média installé absent/corrompu.');}}pack.folder=folder;cache.set(id,{stamp,pack});return pack;}catch{return null;}}
 function installed(){storageWarning=null;try{if(!fs.existsSync(root))return [];confined(root);return fs.readdirSync(root).filter(n=>!n.startsWith('.')).map(read).filter(Boolean).map(p=>p.meta).sort((a,b)=>a.name.localeCompare(b.name));}catch(e){storageWarning='Stockage des packs indisponible : '+e.message;return [];}}
 function inspect(file){preview=null;preview=analyse(file,database).meta;return preview;}
 function install(file,digest){
  check(typeof digest==='string'&&/^[a-f0-9]{64}$/.test(digest),'empreinte de confirmation requise.');
  const pack=analyse(file,database);check(pack.meta.digest===digest,'archive changée depuis l’analyse.');
  confined(root);fs.mkdirSync(root,{recursive:true});confined(root);
  const target=path.join(root,pack.meta.id);cache.delete(pack.meta.id);
  if(fs.existsSync(target)){confined(target);if(read(pack.meta.id))return pack.meta;}
  const stage=path.join(root,'.staging-'+crypto.randomUUID()),backup=path.join(root,'.previous-'+crypto.randomUUID());let moved=false;
  fs.mkdirSync(stage);
  try{
   confined(stage);
   for(const [n,data]of pack.files)fs.writeFileSync(path.join(stage,n),data,{flag:'wx'});
   fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify({meta:pack.meta,clubs:pack.clubs,players:pack.players}),{flag:'wx'});
   confined(target);
   if(fs.existsSync(target)){fs.renameSync(target,backup);moved=true;}
   try{fs.renameSync(stage,target);}catch(error){if(moved)fs.renameSync(backup,target);throw error;}
  }catch(e){
   if(fs.existsSync(stage)&&!fs.lstatSync(stage).isSymbolicLink())fs.rmSync(stage,{recursive:true,force:true});
   throw Error('Installation impossible : '+e.message);
  }
  // A retained previous directory is harmless if cleanup fails. Never undo a
  // successfully published pack because of a nonessential cleanup operation.
  if(moved){try{fs.rmSync(backup,{recursive:true,force:true});}catch{}}
  cache.delete(pack.meta.id);return pack.meta;
 }

 function get(id){return id==='base'?null:read(id);}
 function project(model,binding,creation){const active=binding?get(binding.id):null,creationPack=get(creation),missing=[];if(binding&&(!active||active.meta.digest!==binding.digest))missing.push('Pack de carrière absent : '+binding.id+'. Présentation de base ; réimportez le pack.');if(creation!=='base'&&!creationPack)missing.push('Pack de création absent : '+creation+'. Présentation de base.');const chosen=missing.some(x=>x.startsWith('Pack de carrière'))?null:active;
  const replacements=new Map();if(chosen){for(const c of database.clubs){const cp=chosen.clubs[c.id];if(cp?.name)replacements.set(c.name,cp.name);for(const p of c.players){const pp=chosen.players[p.id];if(pp?.name)replacements.set(p.name,pp.name);}}for(const c of model.meta.catalogue){if(chosen.clubs[c.id]?.name)replacements.set(c.name,chosen.clubs[c.id].name);}}
  const escaped=[...replacements.keys()].filter(Boolean).sort((a,b)=>b.length-a.length).map(s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'));const pattern=escaped.length?new RegExp(escaped.join('|'),'gu'):null;
  function walk(value,pack,replace){if(typeof value==='string')return replace&&pattern?value.replace(pattern,s=>replacements.get(s)):value;if(!value||typeof value!=='object')return value;if(Array.isArray(value))return value.map(x=>walk(x,pack,replace));const out={};for(const [k,v]of Object.entries(value))out[k]=['id','playerId','outId','inIds','eligibleIds','captain','kicker','pair','slug','dataDir','database','exportText'].includes(k)?v:walk(v,pack,replace);if(pack){const item=typeof value.id==='number'?pack.clubs[value.id]:pack.players[value.id];if(item){if(item.name)out.name=item.name;if(item.abbr)out.abbr=item.abbr;if(item.logo)out.logoPath=path.join(pack.folder,item.logo);if(item.portrait){out.portraitPath=path.join(pack.folder,item.portrait);out.portraitStatus=item.portraitStatus;}}}return out;}
  const catalogue=model.meta.catalogue;model=walk(model,chosen,true);model.meta.catalogue=walk(catalogue,creationPack,false);const list=installed();if(storageWarning)missing.push(storageWarning);model.packs={installed:list,creation,career:binding?.id||'base',missing,preview};return model;
 }
 return {inspect,install,get,project,installed};
}
module.exports={createStore,analyse,readZip,imageInfo,crc32,LIMITS};
