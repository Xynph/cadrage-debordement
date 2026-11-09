'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto');
const media=require('../native/engine/media-packs.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

function png(width=320,height=180,color=100){
 function chunk(type,bytes){
  const kind=Buffer.from(type),head=Buffer.alloc(4),tail=Buffer.alloc(4);
  head.writeUInt32BE(bytes.length);tail.writeUInt32BE(media.crc32(Buffer.concat([kind,bytes])));
  return Buffer.concat([head,kind,bytes,tail]);
 }
 const head=Buffer.alloc(13);head.writeUInt32BE(width);head.writeUInt32BE(height,4);head[8]=8;head[9]=2;
 const pixels=Buffer.alloc((width*3+1)*height,color);
 for(let i=0;i<height;i++)pixels[i*(width*3+1)]=0;
 return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',head),chunk('IDAT',zlib.deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]);
}

function zip(file,items){
 const chunks=[],central=[];let offset=0;
 for(const [name,bytes] of items){
  const n=Buffer.from(name),local=Buffer.alloc(30),index=Buffer.alloc(46),crc=media.crc32(bytes);
  local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt16LE(0x800,6);local.writeUInt32LE(crc,14);local.writeUInt32LE(bytes.length,18);local.writeUInt32LE(bytes.length,22);local.writeUInt16LE(n.length,26);
  index.writeUInt32LE(0x02014b50);index.writeUInt16LE(20,4);index.writeUInt16LE(20,6);index.writeUInt16LE(0x800,8);index.writeUInt32LE(crc,16);index.writeUInt32LE(bytes.length,20);index.writeUInt32LE(bytes.length,24);index.writeUInt16LE(n.length,28);index.writeUInt32LE(offset,42);
  chunks.push(local,n,bytes);central.push(index,n);offset+=30+n.length+bytes.length;
 }
 const listing=Buffer.concat(central),end=Buffer.alloc(22);
 end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(listing.length,12);end.writeUInt32LE(offset,16);
 fs.writeFileSync(file,Buffer.concat([...chunks,listing,end]));return file;
}

test('photos de territoire : import, attribution, détachement et refus sans modifier la carrière',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-atlas-'));
 const profile=path.join(root,'profil'),mode='world-champ';
 let n=0,bridge=createBridge({dataDir:profile,seed:415,now:1788134400000});
 t.after(()=>{bridge.close();fs.rmSync(root,{recursive:true,force:true});});
 const request=(command,payload={})=>bridge.handle({id:++n,command,payload});
 const ok=(command,payload={})=>{const r=request(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const exportState=()=>JSON.parse(ok('export').meta.exportText).state;
 const exportBytes=()=>ok('export').meta.exportText;
 const city=png(),stadium=png(640,360,46);
 const datum=(asset,author)=>({asset,credit:author,source:'https://example.org/photo/'+asset,license:'https://creativecommons.org/licenses/by/4.0/'});
 const cityPhoto=datum('ville','Photographie urbaine · auteur témoin');
 const stadiumPhoto=datum('stade','Enceinte · auteur témoin');
 const m=ok('new_career',{mode,club:30}),state=exportState();
 const manifest={schema:'cd-identity-pack-v3',id:'atlas-temoin',name:'Atlas témoin',version:'1',databaseId:m.meta.champDatabase.id,rightsStatus:'test-local',clubs:[{id:30,photos:{city:cityPhoto,stadium:stadiumPhoto}}],players:[],staff:[],assets:[]};
 const pack=(doc,images=[['ville',city],['stade',stadium]])=>{
  doc={...doc,assets:images.map(([id,bytes])=>({id,path:'territoire/'+id+'.png',sha256:digest(bytes),bytes:bytes.length}))};
  return zip(path.join(root,'pack-'+(++n)+'.zip'),[['pack.json',Buffer.from(JSON.stringify(doc))],...images.map(([id,bytes])=>['territoire/'+id+'.png',bytes])]);
 };
 const withPhotos=photos=>({...manifest,clubs:[{id:30,photos}]});
 const file=pack(manifest),preview=ok('pack_inspect',{mode,path:file}).packs.preview;
 assert.equal(preview.counts.cityPhotos,1);assert.equal(preview.counts.stadiumPhotos,1);
 ok('pack_install',{mode,path:file,digest:preview.digest});
 const selected=ok('pack_select',{mode,scope:'career',id:preview.id});
 const projection=selected.club.presentation.photos;
 assert.deepEqual(Object.keys(projection).sort(),['city','stadium']);
 const {asset,...attribution}=cityPhoto;
 assert.deepEqual({credit:projection.city.credit,source:projection.city.source,license:projection.city.license},attribution);
 assert.equal(digest(fs.readFileSync(projection.city.path)),digest(city));
 assert.equal(digest(fs.readFileSync(projection.stadium.path)),digest(stadium));
 const after=exportState();assert.equal(after.identityPack.id,preview.id);delete after.identityPack;assert.deepEqual(after,state);
 const beforeBytes=exportBytes();
 for(const bad of [
  pack({...manifest,schema:'cd-identity-pack-v2'}),
  pack(withPhotos({city:{...cityPhoto,source:'file:///C:/photos/secret.png'},stadium:stadiumPhoto})),
  pack(withPhotos({city:{...cityPhoto,license:'https://user:secret@example.org/'},stadium:stadiumPhoto})),
  pack(withPhotos({city:{...cityPhoto,credit:'<b>Faux</b>'},stadium:stadiumPhoto})),
  pack(withPhotos({city:{...cityPhoto,asset:'manquant'},stadium:stadiumPhoto})),
  pack(withPhotos({city:cityPhoto,stadium:stadiumPhoto,logo:cityPhoto})),
  pack(withPhotos({city:cityPhoto,stadium:stadiumPhoto}),[['ville',png(24,24)],['stade',stadium]]),
 ]){
  assert.equal(request('pack_inspect',{mode,path:bad}).ok,false);
  assert.equal(exportBytes(),beforeBytes);
 }
 const prior={...manifest,databaseId:m.meta.nationaleDatabase.id};
 assert.equal(request('pack_inspect',{mode:'world-nationale',path:pack(prior)}).ok,false);
 bridge.close();bridge=createBridge({dataDir:profile,seed:999,now:1788134400000});
 assert.equal(ok('snapshot').club.presentation.photos.city.credit,cityPhoto.credit);
 const corrupted=Buffer.from(city);corrupted[corrupted.length-5]^=255;
 fs.writeFileSync(projection.city.path,corrupted);
 const invalid=ok('snapshot');
 assert.equal(invalid.club.presentation.photos,undefined);
 assert.ok(invalid.packs.missing.some(w=>w.includes(preview.id)));
 assert.equal(exportBytes(),beforeBytes,'une photo endommagée ne réécrit pas la carrière');
 fs.writeFileSync(projection.city.path,city);
 assert.equal(ok('snapshot').club.presentation.photos.city.credit,cityPhoto.credit);
 assert.equal(exportBytes(),beforeBytes);
 assert.equal(ok('pack_select',{mode,scope:'career',id:'base'}).club.presentation.photos,undefined);
 assert.deepEqual(exportState(),state);
 const validV2=pack({...manifest,schema:'cd-identity-pack-v2',clubs:[{id:30,city:'Ville de repli'}]},[]);
 assert.equal(ok('pack_inspect',{mode,path:validV2}).packs.preview.counts.cityPhotos,undefined);
});
