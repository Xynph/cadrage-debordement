'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs'),media=require('../native/engine/media-packs.cjs'),db=require('../dist/rugby-common-rosters.js');
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-coach-notes06-pack-')),b=createBridge({dataDir:root,seed:506,now:1700000000000});let seq=0;
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
function archive(manifest){const name=Buffer.from('pack.json'),data=Buffer.from(JSON.stringify(manifest)),crc=media.crc32(data),local=Buffer.alloc(30),central=Buffer.alloc(46),end=Buffer.alloc(22);local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt16LE(0x800,6);local.writeUInt32LE(crc,14);local.writeUInt32LE(data.length,18);local.writeUInt32LE(data.length,22);local.writeUInt16LE(name.length,26);central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt16LE(0x800,8);central.writeUInt32LE(crc,16);central.writeUInt32LE(data.length,20);central.writeUInt32LE(data.length,24);central.writeUInt16LE(name.length,28);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(central.length+name.length,12);end.writeUInt32LE(local.length+name.length+data.length,16);return Buffer.concat([local,name,data,central,name,end]);}
try{
 let m=settleClubMeetings(good('new_career',{mode:'common',club:0}),(command,payload)=>good(command,payload));const p=m.squad[0],text=p.name+' & le projet <calme> 😀';
 m=good('coach_note_save',{context:m.clubLife.coachNotebook.context,target:p.id,text});const saved=good('export').meta.exportText;
 const manifest={schema:'cd-identity-pack-v1',id:'carnet-temoin',name:'Carnet identité témoin',version:'1',databaseId:db.id,rightsStatus:'test-local',clubs:[],players:[{id:p.id,name:'Identité synthétique témoin'}],assets:[]},file=path.join(root,'pack.zip');fs.writeFileSync(file,archive(manifest));
 const pack=good('pack_inspect',{path:file}).packs.preview;good('pack_install',{path:file,digest:pack.digest});m=settleClubMeetings(good('pack_select',{id:pack.id,scope:'career'}),(command,payload)=>good(command,payload));
 assert.equal(m.clubLife.coachNotebook.entries[0].name,'Identité synthétique témoin');assert.equal(m.clubLife.coachNotebook.entries[0].text,text,'Le texte personnel ne suit pas les substitutions de noms du pack');
 assert.equal(m.clubLife.coachNotebook.targets.find(t=>t.target===p.id).name,'Identité synthétique témoin');
 const exported=JSON.parse(good('export').meta.exportText);assert.deepEqual(exported.state.coachNotebook,JSON.parse(saved).state.coachNotebook,'Aucun nom de pack figé dans la note');
 m=settleClubMeetings(good('pack_select',{id:'base',scope:'career'}),(command,payload)=>good(command,payload));assert.equal(m.clubLife.coachNotebook.entries[0].name,p.name);assert.equal(m.clubLife.coachNotebook.entries[0].text,text);
 console.log('Carnet06 pack synthétique PASS : identité par ID courant, texte littéral intact, données de carrière inchangées, retour base. Preuves : '+root);
}finally{b.close();}
