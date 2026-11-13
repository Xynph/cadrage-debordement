'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {advanceToNextMatch}=require('./helpers/monde-matchs.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-relationships-'));
let b,seq=0;
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const bad=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,false,command+' doit être refusé');return r;};
try{
 b=createBridge({dataDir:root,seed:371,now:1700000000000});
 let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:29}),good);
 assert.ok(m.clubLife?.relationships,'Le vrai worker doit exposer les relations du club 29.');
 const rel=()=>m.clubLife.relationships,ctx=()=>rel().context;
 const before=good('export').meta.exportText,bytes=fs.readFileSync(path.join(m.meta.dataDir,'donnees.json'));
 assert.equal(JSON.parse(before).state.v70Relations,undefined);assert.equal(JSON.parse(before).state.livingLockerRoom,undefined);assert.equal(JSON.parse(before).state.interclubWorld,undefined,'Les consultations ne doivent pas activer un namespace optionnel.');
 for(let i=0;i<3;i++)good('snapshot');
 assert.equal(good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(path.join(m.meta.dataDir,'donnees.json')),bytes);
 const p=rel().players[0],sat=p.score,morale=m.meta.morale;
 m=good('relationship_conversation',{context:ctx(),playerId:p.id,choice:'rassurer'});
 assert.equal(rel().players.find(x=>x.id===p.id).score,Math.min(95,sat+1));assert.equal(m.meta.morale,Math.min(98,morale+1));
 bad('relationship_conversation',{context:ctx(),playerId:p.id,choice:'rassurer'});
 const second=rel().players[1];m=good('relationship_conversation',{context:ctx(),playerId:second.id,choice:'rassurer'});assert.equal(m.meta.morale,Math.min(98,morale+1));
 m=good('relationship_promise',{context:ctx(),playerId:p.id,target:'rotation'});assert.equal(rel().players.find(x=>x.id===p.id).promise.target,'rotation');
 bad('relationship_promise',{context:ctx(),playerId:p.id,target:'rotation'});
 const a=rel().players.find(x=>!x.injury&&x.condition>=45),bb=rel().players.find(x=>x.id!==a.id&&!x.injury&&x.condition>=45),cond=a.condition;
 m=good('relationship_duo',{context:ctx(),mode:'duo',a:a.id,b:bb.id});assert.equal(rel().players.find(x=>x.id===a.id).condition,cond-2);assert.equal(rel().pairs.length,1);
 bad('relationship_duo',{context:ctx(),mode:'duo',a:a.id,b:bb.id});
 const event=rel().event;
 m=good('locker_room_decision',{context:ctx(),eventKey:event.key,choice:'responsabiliser'});assert.equal(rel().commitments.length,1);assert.equal(rel().event,null);
 bad('locker_room_decision',{context:ctx(),eventKey:event.key,choice:'ecouter'});
 bad('relationship_conversation',{context:{...ctx(),week:ctx().week+1},playerId:p.id,choice:'ecouter'});
 const saved=good('export').meta.exportText;
 for(const alter of [s=>s.v70Relations.version=999,s=>s.v70Relations.pairs[0].score=61,s=>s.livingLockerRoom.version=999,s=>s.livingLockerRoom.commitments[0].dueWeek--,s=>s.livingLockerRoom.history.push(s.livingLockerRoom.history[0])]){
  const doc=JSON.parse(saved);alter(doc.state);const r=bad('import',{text:JSON.stringify(doc)});assert.match(r.error,/vestiaire/i);assert.equal(good('export').meta.exportText,saved);
 }
 good('shutdown');b=createBridge({dataDir:root});assert.equal(good('export').meta.exportText,saved,'Reprise fidèle.');m=good('snapshot');
 const profileFile=path.join(m.meta.dataDir,'donnees.json'),disk=fs.readFileSync(profileFile);
 const rollback=good('export').meta.exportText;
 refuseSavePublication(profileFile,()=>bad('relationship_conversation',{context:ctx(),playerId:rel().players[2].id,choice:'ecouter'}));
 assert.equal(good('export').meta.exportText,rollback);assert.deepEqual(fs.readFileSync(profileFile),disk);
 settleClubMeetings(good('train'),good);bad('relationship_duo',{context:ctx(),mode:'duo',a:a.id,b:bb.id});m=advanceToNextMatch(good('snapshot'),good);good('auto_lineup');good('begin_match');bad('relationship_conversation',{context:ctx(),playerId:rel().players[2].id,choice:'ecouter'});good('delegate');m=settleClubMeetings(good('finish_round'),good);
 assert.ok(m.clubLife.clubWorld.events.length>=15,'Monde : observation d’au moins quinze vraies rencontres.');
 const afterMatch=good('export').meta.exportText;
 for(const alter of [s=>s.interclubWorld.version=999,s=>s.interclubWorld.pairs[Object.keys(s.interclubWorld.pairs)[0]].games++,s=>s.interclubWorld.events[0].winner=999,s=>s.interclubWorld.seen.push(s.interclubWorld.seen[0])]){
  const doc=JSON.parse(afterMatch);alter(doc.state);const r=bad('import',{text:JSON.stringify(doc)});assert.match(r.error,/interclubs/i);assert.equal(good('export').meta.exportText,afterMatch);
 }
 const source=JSON.parse(fs.readFileSync(path.join(m.meta.dataDir,'donnees.json'),'utf8')),state=JSON.parse(source.store['bdt-v1']);state.livingLockerRoom.version=999;source.store['bdt-v1']=JSON.stringify(state);
 const hostile=path.join(root,'hostile','PrototypeGodot');fs.mkdirSync(hostile,{recursive:true});const hostileFile=path.join(hostile,'donnees.json'),hostileBytes=JSON.stringify(source);fs.writeFileSync(hostileFile,hostileBytes);
 good('shutdown');b=createBridge({dataDir:hostile});m=good('snapshot');assert.match(m.meta.profileError,/vestiaire/i);assert.equal(m.meta.hasCareer,false);assert.equal(fs.readFileSync(hostileFile,'utf8'),hostileBytes,'Le profil refusé reste intact.');
 good('shutdown');b=createBridge({dataDir:path.join(root,'legacy'),seed:371,now:1700000000000});settleClubMeetings(good('new_career',{mode:'world-champ',club:0}),good);
 const old=JSON.parse(good('export').meta.exportText);delete old.state.satisfactionVersion;delete old.state.relationsVersion;delete old.state.objectivesVersion;delete old.state.economy.objectives;delete old.state.economy.objectiveHistory;delete old.state.economy.relationLog;delete old.state.economy.moodLog;for(const c of old.state.clubs)for(const p of c.players)delete p.satisfaction;
 let hash=2166136261;for(const ch of JSON.stringify(old.state))hash=Math.imul(hash^ch.charCodeAt(0),16777619);old.checksum=(hash>>>0).toString(16).padStart(8,'0');
 m=good('import',{text:JSON.stringify(old)});assert.equal(rel().active,false);assert.equal(JSON.parse(good('export').meta.exportText).state.satisfactionVersion,undefined);
 m=good('relationship_activate',{context:ctx()});assert.equal(rel().active,true);assert.equal(rel().players[0].score,65);bad('relationship_activate',{context:ctx()});m=good('relationship_conversation',{context:ctx(),playerId:rel().players[0].id,choice:'ecouter'});assert.equal(rel().players[0].score,67);
 console.log('Relations natives : conversations, promesses, duos, événement, lecture pure, reprise et rollback disque PASS.');
}finally{b?.close();}
