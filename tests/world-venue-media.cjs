'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
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
 const m=settleClubMeetings(ok('new_career',{mode,club:30}),(command,payload)=>ok(command,payload)),state=exportState();
 const manifest={schema:'cd-identity-pack-v3',id:'atlas-temoin',name:'Atlas témoin',version:'1',databaseId:m.meta.champDatabase.id,rightsStatus:'test-local',clubs:[{id:30,photos:{city:cityPhoto,stadium:stadiumPhoto}}],players:[],staff:[],assets:[]};
 const pack=(doc,images=[['ville',city],['stade',stadium]])=>{
  doc={...doc,assets:images.map(([id,bytes])=>({id,path:'territoire/'+id+'.png',sha256:digest(bytes),bytes:bytes.length}))};
  return zip(path.join(root,'pack-'+(++n)+'.zip'),[['pack.json',Buffer.from(JSON.stringify(doc))],...images.map(([id,bytes])=>['territoire/'+id+'.png',bytes])]);
 };
 const withPhotos=photos=>({...manifest,clubs:[{id:30,photos}]});
 const file=pack(manifest),preview=ok('pack_inspect',{mode,path:file}).packs.preview;
 assert.equal(preview.counts.cityPhotos,1);assert.equal(preview.counts.stadiumPhotos,1);
 ok('pack_install',{mode,path:file,digest:preview.digest});
 const selected=settleClubMeetings(ok('pack_select',{mode,scope:'career',id:preview.id}),(command,payload)=>ok(command,payload));
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
 assert.equal(settleClubMeetings(ok('pack_select',{mode,scope:'career',id:'base'}),(command,payload)=>ok(command,payload)).club.presentation.photos,undefined);
 assert.deepEqual(exportState(),state);
 const validV2=pack({...manifest,schema:'cd-identity-pack-v2',clubs:[{id:30,city:'Ville de repli'}]},[]);
 assert.equal(ok('pack_inspect',{mode,path:validV2}).packs.preview.counts.cityPhotos,undefined);
});

test('identités de compétition : dossier de création, affichage et retour à la base',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-league-identity-')),mode='world-champ';
 const bridge=createBridge({dataDir:path.join(root,'profil'),seed:415,now:1788134400000});
 t.after(()=>{bridge.close();fs.rmSync(root,{recursive:true,force:true});});
 let n=0;
 const request=(command,payload={})=>bridge.handle({id:++n,command,payload});
 const ok=(command,payload={})=>{const r=request(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const initial=ok('snapshot'),overview=initial.meta.champCatalogue.find(c=>c.id===30).startingRoster;
 assert.ok(overview.average>0&&overview.forwards>0&&overview.backs>0);
 assert.ok(overview.strengthDetail?.starters.rank>0&&overview.weaknessDetail?.reserves.rank>0);
 const toulouse=initial.meta.champCatalogue.find(c=>c.id===0);
 assert.equal(toulouse.history.founded,1907);
 assert.ok(toulouse.history.bio.includes('jeu de mouvement'));
 assert.ok(toulouse.history.results.some(row=>row.competition==='elite'&&row.titles===25&&row.year===2026));
 assert.equal(initial.meta.creationCompetitions[mode].prem.name,'Élite anglaise');
 const photo=png(),file=path.join(root,'identites.zip');
 const manifest={schema:'cd-identity-pack-v4',id:'ligue-temoin',name:'Ligues témoins',version:'1',databaseId:initial.meta.champDatabase.id,rightsStatus:'test-local',
  clubs:[{id:30,photos:{stadium:{asset:'photo',credit:'Témoin',source:'https://example.org/photo',license:'https://example.org/license'}}}],players:[],staff:[],
  competitions:[{id:'prem',name:'Championnat témoin',logo:'photo'}],assets:[{id:'photo',path:'photo.png',sha256:digest(photo),bytes:photo.length}]};
 const write=(changes={})=>zip(file,[['pack.json',Buffer.from(JSON.stringify({...manifest,...changes}))],['photo.png',photo]]);
 for(const competitions of [[{id:'__proto__',name:'Inconnu',logo:'photo'}],[manifest.competitions[0],manifest.competitions[0]],[{id:'prem',name:'<b>Invalide</b>',logo:'photo'}]]){
  assert.equal(request('pack_inspect',{mode,path:write({competitions})}).ok,false);
 }
 const preview=ok('pack_inspect',{mode,path:write()}).packs.preview;
 assert.equal(preview.counts.competitions,1);assert.equal(preview.counts.competitionLogos,1);
 ok('pack_install',{mode,path:file,digest:preview.digest});
 const creation=settleClubMeetings(ok('pack_select',{mode,scope:'creation',id:preview.id}),(command,payload)=>ok(command,payload));
 const identity=creation.meta.creationCompetitions[mode].prem;
 assert.equal(identity.name,'Championnat témoin');
 assert.equal(digest(fs.readFileSync(identity.logoPath)),digest(photo));
 assert.equal(creation.meta.champCatalogue.find(c=>c.id===30).photos.stadium.path,identity.logoPath);
 assert.deepEqual(creation.meta.champCatalogue.find(c=>c.id===0).history,toulouse.history);
 // Compare the reference catalogue with an unvaried starting roster.
 const career=settleClubMeetings(ok('new_career',{mode,club:30,varyCurrent:false}),(command,payload)=>ok(command,payload));
 assert.equal(career.leagues.find(l=>l.id==='prem').name,identity.name);
 assert.equal(career.clubLife.press.journal.divisions.find(d=>d.id==='prem').label,identity.name);
 assert.equal(career.leagues.find(l=>l.id==='prem').logoPath,identity.logoPath);
 assert.ok(career.calendar.filter(f=>f.competitionId==='prem').every(f=>f.label.startsWith(identity.name)));
 const raw=ok('export').meta.exportText;assert.ok(!raw.includes(identity.logoPath));
 const state=JSON.parse(raw).state,players=state.clubs[30].players;
 assert.equal(state.careerVariation.varyCurrent,false);
 assert.equal(overview.forwards+overview.backs,players.length);
 assert.equal(overview.average,Math.round(players.reduce((n,p)=>n+p.rating,0)/players.length*10)/10);
 const positions={
  Piliers:[[1,'Pilier gauche'],[1,'Pilier droit']],Talonneurs:[[1,'Talonneur']],'Deuxièmes lignes':[[2,'Deuxième ligne']],
  'Troisièmes lignes':[[3,'Troisième ligne','Numéro 8']],'Demis de mêlée':[[1,'Demi de mêlée']],
  'Demis d’ouverture':[[1,'Demi d’ouverture']],Ailiers:[[2,'Ailier']],Centres:[[2,'Centre']],Arrières:[[1,'Arrière']],
 };
 const clubs=initial.meta.champCatalogue.filter(c=>c.division==='prem');
 for(const [group,detail] of [[overview.strengths,overview.strengthDetail],[overview.needs,overview.weaknessDetail]]){
  assert.equal(detail.clubs,clubs.length);
  const lanes=positions[group];
  for(const [line,offset] of [['starters',0],['reserves',1]]){
   const entries=clubs.map(({id})=>{
    const squad=state.clubs[id].players;
    const picked=lanes.flatMap(([size,...roles])=>squad.filter(p=>roles.includes(p.pos))
     .sort((a,b)=>b.rating-a.rating).slice(offset*size,(offset+1)*size));
    return {id,filled:picked.length,score:picked.reduce((sum,p)=>sum+p.rating,0)};
   });
   entries.sort((a,b)=>b.filled-a.filled||b.score-a.score);
   const team=entries.find(entry=>entry.id===30);
   const matches=entries.filter(entry=>entry.filled===team.filled&&entry.score===team.score);
   assert.deepEqual(detail[line],{
    rank:entries.indexOf(matches[0])+1,tied:matches.length>1,filled:team.filled,
    expected:lanes.reduce((sum,[size])=>sum+size,0),
   });
  }
 }
 assert.deepEqual(creation.meta.champCatalogue.find(c=>c.id===30).startingRoster,overview);
 const base=settleClubMeetings(ok('pack_select',{mode,scope:'career',id:'base'}),(command,payload)=>ok(command,payload));
 assert.equal(base.leagues.find(l=>l.id==='prem').name,'Élite anglaise');
 assert.equal(base.clubLife.press.journal.divisions.find(d=>d.id==='prem').label,'Élite anglaise');
 assert.equal(base.leagues.find(l=>l.id==='prem').logoPath,undefined);
 assert.ok(base.calendar.filter(f=>f.competitionId==='prem').every(f=>f.label.startsWith('Élite anglaise')));
});
