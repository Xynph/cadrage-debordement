'use strict';
// Shared by the base-names worker suites: new careers carry the base names; an identity
// pack still applies by identifier; a career started on an earlier table of names loads
// and keeps its names.
const {settleClubMeetings}=require('./club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../../native/engine/media-packs.cjs'),{createBridge}=require('../../native/engine/worker.cjs'),baseNames=require('../../scripts/base-names.cjs');
let root=null,seq=0;
const playerNames=baseNames.players(),staffNames=baseNames.staff(),clone=value=>JSON.parse(JSON.stringify(value));
// Stored ZIP with a single manifest: the smallest archive the pack reader accepts.
function archive(manifest){
 const name=Buffer.from('pack.json'),data=Buffer.from(JSON.stringify(manifest)),crc=media.crc32(data),local=Buffer.alloc(30),central=Buffer.alloc(46),end=Buffer.alloc(22);
 local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt16LE(0x800,6);local.writeUInt32LE(crc,14);local.writeUInt32LE(data.length,18);local.writeUInt32LE(data.length,22);local.writeUInt16LE(name.length,26);
 central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt16LE(0x800,8);central.writeUInt32LE(crc,16);central.writeUInt32LE(data.length,20);central.writeUInt32LE(data.length,24);central.writeUInt16LE(name.length,28);
 end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(46+name.length,12);end.writeUInt32LE(30+name.length+data.length,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([local,name,data,central,name,end]));return file;
}
function sign(doc){const raw=JSON.stringify(doc.state);let hash=2166136261;for(let i=0;i<raw.length;i++)hash=Math.imul(hash^raw.charCodeAt(i),16777619);doc.checksum=(hash>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
const strings=model=>{const found=[];(function walk(value){if(typeof value==='string')found.push(value);else if(Array.isArray(value))value.forEach(walk);else if(value&&typeof value==='object')for(const [key,item] of Object.entries(value))if(key!=='exportText')walk(item);})(model);return found;};
const sourced=state=>[...state.clubs.flatMap(club=>club.players),...state.market,...state.economy.freeAgents].filter(p=>playerNames.has(p.id));
const references=state=>state.staffCareer.people.flat().filter(p=>p.sourceKind==='reference');

function scenario(directory,mode,club,expectedPlayers){
 root=directory;
 const b=createBridge({dataDir:path.join(root,mode),seed:20261111,now:1794178800000});
 const raw=(command,payload={})=>b.handle({id:++seq,command,payload});
 const good=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,mode+' '+command+' : '+r.error);return r.model;};
 const settled=(command,payload={})=>settleClubMeetings(good(command,payload),good);
 const exported=()=>JSON.parse(good('export').meta.exportText);
 try{
  let m=settled('new_career',{mode,club});
  const fresh=exported(),state=fresh.state;

  // A new career: every player and staff member of the registry carries the name of the table.
  assert.equal(sourced(state).length,expectedPlayers);
  for(const p of sourced(state))assert.equal(p.name,playerNames.get(p.id),p.id);
  assert.ok(references(state).length>=400);
  for(const p of references(state))assert.equal(p.name,staffNames.get(p.sourceStaffId),p.sourceStaffId);
  const prefix=mode==='common'?'lnr:':'world:',player=m.squad.find(p=>p.id.startsWith(prefix)),french=m.squad.find(p=>p.id.startsWith('lnr:'));
  const member=m.staff.teams.find(team=>team.id===club).members.find(p=>staffNames.has(p.sourceStaffId));
  assert.ok(player&&member,'un joueur du registre et un staff de référence dans le club dirigé');
  assert.equal(player.name,playerNames.get(player.id));assert.equal(member.name,staffNames.get(member.sourceStaffId));

  // An obviously fake pack: same identifiers, other names.
  const databaseId=m.meta.database.id;
  const manifest={schema:'cd-identity-pack-v2',id:'temoin-noms-'+mode,name:'Témoin des noms',version:'1',databaseId,rightsStatus:'test-local',clubs:[],
   players:[{id:player.id,name:'Joueur Test 1'},...(french&&french.id!==player.id?[{id:french.id,name:'Joueur Test 2'}]:[])],staff:[{id:member.sourceStaffId,name:'Staff Test 1'}],assets:[]};
  const zip=archive(manifest),preview=good('pack_inspect',{path:zip,mode}).packs.preview;
  assert.deepEqual([preview.counts.players,preview.counts.staff],[manifest.players.length,1]);
  good('pack_install',{path:zip,digest:preview.digest,mode});
  m=settled('pack_select',{scope:'career',id:preview.id,mode});
  const shown=model=>({player:model.squad.find(p=>p.id===player.id).name,staff:model.staff.teams.find(team=>team.id===club).members.find(p=>p.sourceStaffId===member.sourceStaffId).name});
  assert.deepEqual(shown(m),{player:'Joueur Test 1',staff:'Staff Test 1'},'le pack s’applique aux mêmes identifiants');
  if(manifest.players.length===2)assert.equal(m.squad.find(p=>p.id===french.id).name,'Joueur Test 2','joueur français d’un club du Monde');
  assert.ok(!strings(m).some(text=>text.includes(playerNames.get(player.id))||text.includes(staffNames.get(member.sourceStaffId))),'aucun nom de base remplacé ne reste affiché');
  const bound=exported().state;assert.equal(bound.identityPack.id,preview.id);delete bound.identityPack;
  assert.deepEqual(bound,state,'le pack ne s’écrit jamais dans la carrière');
  m=settled('pack_select',{scope:'career',id:'base',mode});
  assert.deepEqual(shown(m),{player:playerNames.get(player.id),staff:staffNames.get(member.sourceStaffId)});

  // A career started on an earlier table of names: other names on the same identifiers, quoted in its archives.
  const earlier=clone(fresh),renamed=new Map();
  const rename=(person,id,label)=>{if(!renamed.has(id))renamed.set(id,label+' '+(renamed.size+1));person.name=renamed.get(id);};
  for(const p of sourced(earlier.state))rename(p,p.id,'Ancien Joueur');
  for(const p of references(earlier.state))rename(p,p.sourceStaffId,'Ancien Staff');
  const formerPlayer=renamed.get(player.id),formerStaff=renamed.get(member.sourceStaffId),quote=formerPlayer+' reprend l’entraînement collectif.';
  earlier.state.news.unshift(quote);
  const press=clone(earlier.state.pressConference);assert.ok(press.history.length>0,'des réponses de presse déjà archivées');
  m=settled('import',{text:sign(earlier)});
  assert.deepEqual(exported().state,earlier.state,'la carrière se charge et garde ses noms, ses identifiants et ses archives');
  assert.deepEqual(exported().state.pressConference,press,'questions et réponses de presse archivées intactes');
  assert.deepEqual(shown(m),{player:formerPlayer,staff:formerStaff});
  assert.ok(strings(m).includes(quote));
  // The pack still shows its names on that career, in lists and in the texts that quote the earlier names.
  m=settled('pack_select',{scope:'career',id:preview.id,mode});
  assert.deepEqual(shown(m),{player:'Joueur Test 1',staff:'Staff Test 1'});
  assert.ok(strings(m).includes('Joueur Test 1 reprend l’entraînement collectif.'),'texte archivé suivi par le pack');
  assert.ok(!strings(m).some(text=>text.includes(formerPlayer+' ')||text===formerPlayer||text===formerStaff),'aucun ancien nom remplacé ne reste affiché');
  m=settled('pack_select',{scope:'career',id:'base',mode});
  // It can be played and saved again, then reopened from disk.
  good('auto_lineup');if(!good('snapshot').selection.valid)good('promote_cover',{confirmed:true});
  if(good('snapshot').next){good('begin_match');good('delegate');}
  m=settled('finish_round');
  const played=exported().state;
  for(const p of sourced(played))assert.equal(p.name,renamed.get(p.id),p.id+' garde son nom après une semaine jouée');
  for(const p of references(played))assert.equal(p.name,renamed.get(p.sourceStaffId));
  const saved=exported().state;good('shutdown');

  // Unsafe names are still refused, whatever the table.
  for(const value of ['<b>Nom</b>','']){
   const unsafe=clone(fresh);sourced(unsafe.state)[0].name=value;
   const check=createBridge({dataDir:path.join(root,mode+'-refus-'+(++seq)),seed:1,now:1794178800000});
   try{assert.equal(check.handle({id:++seq,command:'import',payload:{text:sign(unsafe)}}).ok,false,'nom refusé : '+JSON.stringify(value));}finally{check.close();}
  }
  return {mode,players:sourced(state).length,staff:references(state).length,saved};
 }finally{b.close();}
}
module.exports={scenario};
