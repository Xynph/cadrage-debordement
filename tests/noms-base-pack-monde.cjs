'use strict';
// Mode Monde : la base du jeu porte des noms inventés (data/names) ; une carrière garde les noms de sa
// sauvegarde ; un pack d'identités (ici un pack de test, aucun nom réel) remplace les noms par identifiant.
// 1. Une carrière créée avec d'anciens noms de base les garde après la mise à jour de la base.
// 2. Une nouvelle carrière affiche les noms des tables de base, joueurs et staffs, sur ses 116 clubs.
// 3. Un pack importé affiche ses noms sur les mêmes identifiants, sans toucher à l'état ; « base » les retire.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),baseNames=require('../scripts/base-names.cjs');
const registry=require('../native/engine/world-registry.json'),{createBridge}=require('../native/engine/worker.cjs');
const players=baseNames.players(),staffNames=baseNames.staff();
const ext=require('../native/engine/world-pacific-registry.cjs'),engineJson=f=>JSON.parse(fs.readFileSync(path.join(__dirname,'../native/engine',f),'utf8'));
// Identifiant de la base complète du Monde (116 clubs), celui auquel un pack se rattache.
const CHAMP_ID=ext.extendChampRegistry(ext.extendNationaleRegistry(ext.extendJapanRegistry(ext.extendWorldRegistry(structuredClone(registry),engineJson('world-pacific-extension.json')),engineJson('world-japan-extension.json')),engineJson('world-nationale-extension.json')),engineJson('world-champ-extension.json')).id;
const root=fs.mkdtempSync(path.join(process.env.CD_TEST_ROOT||os.tmpdir(),'cd-noms-base-'));let seq=0;
function archive(manifest){
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))]];let offset=0;const blocks=[],central=[];
 for(const [name,data] of items){
  const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);
  l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);
  c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);
  blocks.push(l,n,data);central.push(c,n);offset+=l.length+n.length+data.length;
 }
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}
function session(dir){
 let b=createBridge({dataDir:dir,seed:4242,now:1700000000000});
 const withMode=(command,payload)=>command.startsWith('pack_')?{mode:'world-champ',...payload}:payload;
 const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload:withMode(command,payload)});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 return {good,settle:model=>settleClubMeetings(model,(command,payload)=>good(command,payload)),state:()=>JSON.parse(good('export').meta.exportText).state,reopen(){good('shutdown');b.close();b=createBridge({dataDir:dir});},close:()=>b.close()};
}
const CLUB=1,club=registry.clubs[CLUB];
assert.ok(club.players.length>=30&&club.players.every(p=>p.id.startsWith('lnr:')),'club français de la base');
const OLD=new Map(club.players.map((p,i)=>[p.id,'Ancien Nom '+String.fromCharCode(65+i%26)+(i>=26?String.fromCharCode(65+Math.floor(i/26)):'')]));
const named=(list,table)=>list.filter(p=>table.has(p.id));
try{
 // 1. Carrière créée quand la base portait d'autres noms (anciennes versions de la base).
 const saved=club.players.map(p=>p.name);
 club.players.forEach(p=>{p.name=OLD.get(p.id);});
 const oldDir=path.join(root,'ancienne');let a=session(oldDir);
 try{
  let m=a.settle(a.good('new_career',{mode:'world-champ',club:CLUB}));
  const before=a.state().clubs[CLUB].players;assert.ok(named(before,OLD).length>=20);
  for(const p of named(before,OLD))assert.equal(p.name,OLD.get(p.id),'nom enregistré à la création '+p.id);
  club.players.forEach((p,i)=>{p.name=saved[i];});
  a.reopen();m=a.good('snapshot');
  const after=a.state().clubs[CLUB].players;
  for(const p of named(after,OLD))assert.equal(p.name,OLD.get(p.id),'la carrière existante garde le nom de sa sauvegarde '+p.id);
  for(const p of (m.squad||[]).filter(p=>OLD.has(p.id)))assert.equal(p.name,OLD.get(p.id),'effectif affiché depuis la sauvegarde '+p.id);
 }finally{club.players.forEach((p,i)=>{p.name=saved[i];});a.close();}

 // 2. Nouvelle carrière : noms des tables de base, joueurs et staffs, partout.
 const s=session(path.join(root,'nouvelle'));
 try{
  let m=s.settle(s.good('new_career',{mode:'world-champ',club:CLUB}));
  const state=s.state();assert.equal(state.clubs.length,116);
  let checked=0;
  for(const c of state.clubs)for(const p of named(c.players,players)){assert.equal(p.name,players.get(p.id),'nouvelle carrière : nom de base '+p.id);checked++;}
  assert.ok(checked>=5000,'au moins 5 000 joueurs de la base vérifiés ('+checked+')');
  assert.ok(state.clubs.some(c=>c.players.some(p=>p.id.startsWith('world:')&&players.has(p.id))),'joueurs étrangers du Monde vérifiés aussi');
  const squad=(m.squad||[]).filter(p=>players.has(p.id));assert.ok(squad.length>=20);
  for(const p of squad)assert.equal(p.name,players.get(p.id),'effectif affiché '+p.id);
  const sid=p=>p.sourceStaffId||p.identity?.id||p.id,members=m.staff.teams[CLUB].members.filter(p=>staffNames.has(sid(p)));assert.ok(members.length>=5,'staff du club issu du registre ('+m.staff.teams[CLUB].members.length+' membres, '+members.length+' nommés)');
  for(const p of members)assert.equal(p.name,staffNames.get(sid(p)),'staff affiché '+sid(p));

  // 3. Pack d'identités de test : mêmes identifiants, noms du pack ; état et RNG inchangés.
  const own=squad.slice(0,3),foreignClub=state.clubs.find(c=>c.players.some(p=>p.id.startsWith('world:')&&players.has(p.id))),foreign=foreignClub.players.find(p=>p.id.startsWith('world:')&&players.has(p.id));
  const coach=members[0];
  const PACK=new Map([[own[0].id,'Ulrich TESTAPACK'],[own[1].id,'Viggo TESTBPACK'],[own[2].id,'Wendel TESTCPACK'],[foreign.id,'Xavi TESTDPACK']]);
  const manifest={schema:'cd-identity-pack-v2',id:'noms-test',name:'Pack de noms de test',version:'1',databaseId:CHAMP_ID,rightsStatus:'test-local',clubs:[],players:[...PACK].map(([id,name])=>({id,name})),staff:[{id:sid(coach),name:'Yanis Testpack'}],assets:[]};
  const withoutPack=v=>{const x=structuredClone(v);delete x.identityPack;return x;};
  const before=s.state();
  const preview=s.good('pack_inspect',{path:archive(manifest)}).packs.preview;
  assert.equal(preview.counts.players,4);
  s.good('pack_install',{path:archive(manifest),digest:preview.digest});
  m=s.settle(s.good('pack_select',{id:preview.id,scope:'career'}));
  for(const p of own)assert.equal(m.squad.find(x=>x.id===p.id).name,PACK.get(p.id),'pack : nom affiché sur le même identifiant '+p.id);
  for(const p of squad.slice(3))assert.equal(m.squad.find(x=>x.id===p.id).name,players.get(p.id),'hors du pack : nom de base '+p.id);
  const shown=m.staff.teams[CLUB].members.find(p=>sid(p)===sid(coach));assert.equal(shown.name,'Yanis Testpack','pack : staff renommé par identifiant');
  assert.deepEqual(withoutPack(s.state()),withoutPack(before),'le pack ne modifie pas la carrière');
  s.reopen();m=s.good('snapshot');
  assert.equal(m.squad.find(x=>x.id===own[0].id).name,PACK.get(own[0].id),'pack conservé à la reprise');
  m=s.settle(s.good('pack_select',{id:'base',scope:'career'}));
  for(const p of own)assert.equal(m.squad.find(x=>x.id===p.id).name,players.get(p.id),'retour à la base : nom de base '+p.id);
  console.log(JSON.stringify({passed:true,ancienneCarriere:named(club.players,OLD).length,nouveauxNomsVerifies:checked,pack:PACK.size+1}));
 }finally{s.close();}
}finally{fs.rmSync(root,{recursive:true,force:true});}
