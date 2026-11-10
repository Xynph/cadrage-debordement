'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-club-world-'));let seq=0,b;
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
function finishWeek(m){m=settleClubMeetings(good('train',{mode:'repos'}),(command,payload)=>good(command,payload));m=good('auto_lineup');if(m.next){if(!m.selection.valid)good('promote_cover',{confirmed:true});good('begin_match');good('delegate');}return settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));}
try{
 b=createBridge({dataDir:root,seed:372,now:1700000000000});let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),(command,payload)=>good(command,payload));
 const context=m.clubLife.relationships.context,event=m.clubLife.relationships.event;
 m=good('locker_room_decision',{context,eventKey:event.key,choice:'responsabiliser'});
 for(let week=0;week<34;week++){
  m=finishWeek(m);
  if(week===1){assert.notEqual(m.clubLife.relationships.commitments[0].status,'open','Échéance réellement contrôlée par managerWeek.');}
  if(week===27){const c=m.clubLife.relationships.context;assert.equal(m.clubLife.relationships.event.available,true);m=good('locker_room_decision',{context:c,eventKey:m.clubLife.relationships.event.key,choice:'ecouter'});assert.equal(m.clubLife.relationships.history[0].week,c.week);}
 }
 assert.equal(m.meta.phase,'ended');const doc=JSON.parse(good('export').meta.exportText),w=doc.state.interclubWorld;
 assert.equal(w.events.length,140);assert.equal(w.seasonMatches,doc.state.history.length);assert.equal(w.seen.length,new Set(doc.state.history.map(h=>h.fixtureId)).size);assert.ok(w.seasonMatches>400);
 assert.equal(w.events.at(-1).phase,'access');assert.equal(w.events.at(-1).winner,doc.state.franceMode.accessMatch.winner);
 m=settleClubMeetings(good('next_season',{confirmed:true}),(command,payload)=>good(command,payload));assert.equal(m.meta.season,2);assert.equal(m.clubLife.clubWorld.years[0].matches,w.seasonMatches);assert.equal(m.clubLife.clubWorld.archives.length,1);assert.equal(m.clubLife.clubWorld.archives[0].champions.length,2);
 const saved=good('export').meta.exportText;good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,saved);
 m=finishWeek(good('snapshot'));assert.equal(m.clubLife.clubWorld.years.length,1);assert.equal(m.clubLife.clubWorld.years[0].matches,w.seasonMatches);
 good('shutdown');b=createBridge({dataDir:path.join(root,'historical'),seed:372,now:1700000000000});settleClubMeetings(good('new_career',{mode:'fiction',club:0}),(command,payload)=>good(command,payload));good('begin_match');good('delegate');m=settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));assert.equal(m.clubLife.clubWorld.events.length,7,'Historique14 : sept vrais résultats.');
 console.log('Monde vrai worker : 34 semaines club29, échéance, >400 résultats uniques, barrage, archives/intersaison/reprise et historique14 PASS. Profil : '+root);
}finally{b?.close();}

