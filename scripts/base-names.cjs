'use strict';
// Display names of the base game, one per player and staff identifier.
// data/names/ is the only source: compilers read it and never derive a name
// from a source identity. Registries whose compiler is not in this repository
// are edited by identifier here (--check verifies them without writing).
const fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'..'),DIR=path.join(ROOT,'data/names'),ENGINE=path.join(ROOT,'native/engine');
const FILES=Object.freeze({frenchPlayers:'noms-joueurs-v1.json',frenchStaff:'noms-staffs-v1.json',worldPlayers:'noms-monde-v1.json',worldStaff:'noms-monde-staffs-v1.json'});
const PLAYER_EXTENSIONS=['world-pacific-extension.json','world-japan-extension.json','world-nationale-extension.json','world-champ-extension.json'];
const STAFF_EXTENSIONS=['world-pacific-staff-extension.json','world-japan-staff-extension.json','world-nationale-staff-extension.json','world-champ-staff-extension.json'];
const readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^﻿/,''));
const valid=name=>typeof name==='string'&&name===name.normalize('NFC')&&name===name.trim()&&name.length>0&&name.length<=120&&!/[<>\x00-\x1f\x7f]|\s\s/.test(name);
function table(file,...sections){
 const doc=readJson(path.join(DIR,file)),names=new Map();
 if(doc.format!=='rugby-legacy-noms-inventes'||doc.version!==1)throw Error('Fichier de noms invalide : '+file);
 for(const section of sections){
  if(!doc[section]||typeof doc[section]!=='object'||Array.isArray(doc[section]))throw Error('Rubrique de noms absente : '+file+' / '+section);
  for(const [id,name] of Object.entries(doc[section])){
   if(names.has(id)||!valid(name))throw Error('Nom de base invalide ou dupliqué : '+id);
   names.set(id,name);
  }
 }
 return names;
}
function merge(...tables){
 const all=new Map();
 for(const names of tables)for(const [id,name] of names){if(all.has(id))throw Error('Identifiant nommé deux fois : '+id);all.set(id,name);}
 return all;
}
const frenchPlayers=()=>table(FILES.frenchPlayers,'noms');
const frenchStaff=()=>table(FILES.frenchStaff,'noms');
const worldPlayers=()=>table(FILES.worldPlayers,'noms','aliasHistoriques');
const worldStaff=()=>table(FILES.worldStaff,'noms');
const players=()=>merge(frenchPlayers(),worldPlayers());
const staff=()=>merge(frenchStaff(),worldStaff());
function nameOf(names,id){
 const name=names.get(id);
 if(name===undefined)throw Error('Nom de base absent : '+id);
 return name;
}
// Rewrites one JSON registry in its published form (two spaces, final newline).
function edit(file,check,change){
 const before=fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n'),data=JSON.parse(before),count=change(data),after=JSON.stringify(data,null,2)+'\n';
 if(after!==before){
  if(check)throw Error('Noms de base périmés : '+path.relative(ROOT,file)+'. Relancer scripts/base-names.cjs.');
  fs.writeFileSync(file,after);
 }
 return count;
}
function apply(check=false){
 const playerNames=worldPlayers(),french=frenchStaff(),world=worldStaff(),report={};
 const rename=(list,names)=>{for(const person of list)person.name=nameOf(names,person.id);return list.length;};
 report['data/world/foreign-inputs.json']=edit(path.join(ROOT,'data/world/foreign-inputs.json'),check,data=>{for(const input of data.players)input.alias=nameOf(playerNames,input.id);return data.players.length;});
 for(const file of PLAYER_EXTENSIONS)report['native/engine/'+file]=edit(path.join(ENGINE,file),check,data=>rename(data.clubs.flatMap(club=>club.players),playerNames));
 report['native/engine/world-legacy-aliases.json']=edit(path.join(ENGINE,'world-legacy-aliases.json'),check,data=>rename(Object.values(data.aliases).map(row=>row.player),playerNames));
 report['native/engine/world-staff-registry.json']=edit(path.join(ENGINE,'world-staff-registry.json'),check,data=>rename(data.clubs.filter(club=>club.id<30).flatMap(club=>club.members),french)+rename(data.clubs.filter(club=>club.id>=30).flatMap(club=>club.members),world));
 for(const file of STAFF_EXTENSIONS)report['native/engine/'+file]=edit(path.join(ENGINE,file),check,data=>rename(data.clubs.flatMap(club=>club.members),world));
 return report;
}
module.exports={FILES,frenchPlayers,frenchStaff,worldPlayers,worldStaff,players,staff,nameOf,valid,apply};
if(require.main===module){
 const check=process.argv.includes('--check'),report=apply(check);
 console.log('Noms de base '+(check?'vérifiés':'appliqués')+' : '+Object.entries(report).map(([file,count])=>file+' '+count).join(', ')+'.');
}
