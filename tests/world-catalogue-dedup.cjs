'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const compose=require('../native/engine/world-pacific-registry.cjs'),terms=require('../native/engine/world-initial-contracts.json'),delta=require('../native/engine/world-champ-extension.json');
const aliases=Object.entries(terms.inactiveAliases),loadLegacy=()=>require('../native/engine/world-legacy-aliases.json');
const variation=require('../native/engine/career-variation.cjs')();
function registry(){const base=require('../native/engine/world-registry.json'),p=compose.extendWorldRegistry(base,require('../native/engine/world-pacific-extension.json')),j=compose.extendJapanRegistry(p,require('../native/engine/world-japan-extension.json')),n=compose.extendNationaleRegistry(j,require('../native/engine/world-nationale-extension.json'));return compose.extendChampRegistry(n,delta);}
test('Le catalogue actif retire réellement les six doublons, seul le lecteur de compatibilité les conserve',()=>{
 const world=registry(),active=new Set(world.clubs.flatMap(c=>c.players.map(p=>p.id)));
 a.equal(world.playerCount,5878);a.equal(active.size,5878);a.equal(delta.clubs.reduce((n,c)=>n+c.players.length,0),596);
 const legacy=loadLegacy();a.equal(legacy.databaseId,world.id);a.equal(Object.keys(legacy.aliases).length,6);
 for(const[id,mapping]of aliases){a.equal(active.has(id),false);a.equal(Object.hasOwn(world.worldProfiles,id),false);a.equal(legacy.aliases[id].canonicalId,mapping.canonicalId);a.equal(legacy.aliases[id].clubId,mapping.clubId);a.equal(legacy.aliases[id].player.id,id);a(active.has(mapping.canonicalId));}
});
function fixture(t,club=112){
 const {createBridge}=require('../native/engine/worker.cjs'),root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-catalogue-dedup-')),opts={dataDir:root,seed:318,now:1788134400000,testVm:true};let b=createBridge(opts),serial=0;
 const raw=(command,payload={})=>b.handle({id:++serial,command,payload}),go=(command,payload={})=>{const r=raw(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});settleClubMeetings(go('new_career',{mode:'world-champ',club}),(command,payload)=>go(command,payload));
 return {root,go,raw,get vm(){return b.vm;},export:()=>go('export').meta.exportText,disk:()=>fs.readFileSync(path.join(root,'PrototypeGodot/donnees.json')),restart:()=>{b.close();b=createBridge({...opts,seed:1,now:1});}};
}
// Empreinte comme le jeu, export réduit compris : tests/helpers/signature-export.cjs.
const {signerExport}=require('./helpers/signature-export.cjs');
function encodedDocument(doc,vm){return signerExport(doc,vm);}
function legacyDocument(text,vm){
 const doc=JSON.parse(text);
 for(const[id,row]of Object.entries(loadLegacy().aliases)){
  const player={...structuredClone(row.player),worldProfile:structuredClone(row.worldProfile)};
  // The source potential follows the policy already declared by this export.
  // Mutable career qualities and the original alias identity remain untouched.
  player.potential=variation.sourcePotential(player.potential,id,doc.state.careerVariation);
  doc.state.clubs[row.clubId].players.push(player);
 }
 return encodedDocument(doc,vm);
}
// Un ancien export ne porte ni familiarité de poste ni rôle promis sur les six fiches historiques : le lecteur les
// ajoute à l'import (familiarite-poste.cjs, role-contrat.cjs : rôle déduit pour l'effectif du manager). Rien d'autre
// ne change : même état au champ près, même RNG, et l'export migré se relit à l'identique.
function importLegacy(h,text){
 h.go('import',{text});const out=h.export(),got=JSON.parse(out),want=JSON.parse(text);
 for(const[alias,row]of Object.entries(loadLegacy().aliases)){
  const mine=got.state.clubs[row.clubId].players.find(p=>p.id===alias),theirs=want.state.clubs[row.clubId].players.find(p=>p.id===alias);
  a(mine&&theirs);a.equal(theirs.familiarite,undefined);a.equal(theirs.roleContrat,undefined);
  a.match(mine.familiarite?.d??'',/^[0-9]{15}$/,alias+' : familiarité de poste ajoutée');theirs.familiarite=mine.familiarite;
  if(row.clubId===got.state.club){a.equal(mine.roleContrat?.deduit,true,alias+' : rôle déduit');a.equal(mine.roleContrat.club,got.state.club);theirs.roleContrat=mine.roleContrat;}
  else a.equal(mine.roleContrat,undefined,alias+' : pas de rôle promis hors du club du manager');
 }
 a.deepEqual(got.state,want.state);a.equal(out,encodedDocument(got,h.vm));
 h.go('import',{text:out});a.equal(h.export(),out,'Export migré relu à l’identique');
 return out;
}
test('Le vrai lecteur conserve les six fiches présentes dans un ancien export : état, RNG et reprise exacts',t=>{
 const sourceCount=text=>JSON.parse(text).state.clubs.flatMap(c=>c.players).filter(p=>!p.id.startsWith('depth-')).length;
 const h=fixture(t),fresh=h.export(),old=legacyDocument(fresh,h.vm),invalid=JSON.parse(old),[id,row]=Object.entries(loadLegacy().aliases)[0];
 const wrong=invalid.state.clubs[row.clubId].players.find(p=>p.id===id);
 a.notEqual(wrong.potential,row.player.potential,'Cette graine distingue le potentiel de carrière du catalogue brut');
 wrong.potential=row.player.potential;
 const before=h.disk(),refused=h.raw('import',{text:encodedDocument(invalid,h.vm)});
 a.equal(refused.ok,false);a.match(refused.error,/profil de joueur mondial incompatible : potential/);
 a.equal(h.export(),fresh);a.deepEqual(h.disk(),before,'Une politique mélangée reste refusée sans modifier le profil');
 const migrated=importLegacy(h,old);a.equal(sourceCount(old),5884);a.equal(sourceCount(migrated),5884);
 const imported=JSON.parse(h.export()).state;
 for(const[alias,source]of Object.entries(loadLegacy().aliases)){
  const player=imported.clubs[source.clubId].players.find(p=>p.id===alias);
  a(player);a.equal(player.name,source.player.name);a.deepEqual(player.worldProfile,source.worldProfile);
 }
 const disk=h.disk();h.go('snapshot');a.deepEqual(h.disk(),disk);h.restart();a.equal(h.export(),migrated);a.deepEqual(h.disk(),disk);
 settleClubMeetings(h.go('new_career',{mode:'world-champ',club:112}),(command,payload)=>h.go(command,payload));a.equal(sourceCount(h.export()),5878);
});
function archive(root,players,assets=[]){
 const media=require('../native/engine/media-packs.cjs'),manifest={schema:'cd-identity-pack-v1',id:'alias-compat-test',name:'Identités fictives de réception',version:'1',databaseId:delta.id,rightsStatus:'synthetic-test-only',clubs:[],players,assets:assets.map(([id,data])=>({id,path:id+'.png',sha256:crypto.createHash('sha256').update(data).digest('hex'),bytes:data.length}))},items=[['pack.json',Buffer.from(JSON.stringify(manifest))],...assets.map(([id,data])=>[id+'.png',data])];
 let offset=0;const chunks=[],central=[];for(const[name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);chunks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);const file=path.join(root,'identities.zip');fs.writeFileSync(file,Buffer.concat([...chunks,cd,end]));return file;
}
test('Un pack historique complet à 5 884 IDs reste accepté, sans autoriser un ID inconnu',t=>{
 const media=require('../native/engine/media-packs.cjs'),root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-all-legacy-ids-'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
 const world=registry(),ids=[...world.clubs.flatMap(c=>c.players.map(p=>p.id)),...aliases.map(([id])=>id)],players=ids.map((id,i)=>({id,name:'Identité fictive '+i}));
 const file=archive(root,players),before=fs.readFileSync(file);a.equal(media.analyse(file,world).meta.counts.players,5884);a.deepEqual(fs.readFileSync(file),before);
 a.throws(()=>media.analyse(archive(root,[{id:'world:champ:00000000000000000000',name:'Inconnu'}]),world),/joueur inconnu/);
});
test('Ancien pack : ID historique accepté, photo reliée au canonique et aucune carrière modifiée',t=>{
 const h=fixture(t),before=JSON.parse(h.export()).state,[id,row]=aliases[0],png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
 const file=archive(h.root,[{id,name:'Variante témoin',portrait:'photo',synthetic:true},{id:row.canonicalId,name:'Canonique témoin'}],[['photo',png]]),original=fs.readFileSync(file),preview=h.go('pack_inspect',{path:file,mode:'world-champ'}).packs.preview;
 h.go('pack_install',{path:file,digest:preview.digest,mode:'world-champ'});let model=settleClubMeetings(h.go('pack_select',{scope:'career',id:preview.id}),(command,payload)=>h.go(command,payload));
 const person=model.squad.find(p=>p.id===row.canonicalId);a(person);a.equal(person.name,'Canonique témoin');a(person.portraitPath);a.deepEqual(fs.readFileSync(person.portraitPath),png);a.equal(person.portraitStatus,'synthetic');
 const after=JSON.parse(h.export()).state;delete after.identityPack;a.deepEqual(after,before);a.deepEqual(fs.readFileSync(file),original);
 const saved=h.export();h.restart();a.equal(h.export(),saved);model=h.go('snapshot');a.equal(model.squad.find(p=>p.id===row.canonicalId).name,'Canonique témoin');
 const legacy=legacyDocument(saved,h.vm),migrated=importLegacy(h,legacy);model=h.go('snapshot');a.equal(model.squad.find(p=>p.id===id).name,'Canonique témoin');a.equal(h.export(),migrated);
});
