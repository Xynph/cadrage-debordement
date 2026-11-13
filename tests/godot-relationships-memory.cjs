'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const sdk=process.env.CD_GODOT_EXECUTABLE;
if(!sdk){console.log('SKIP relationships-memory : SDK Godot requis, aucune réception graphique revendiquée.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-relationships-memory-'));
const b=createBridge({dataDir:path.join(dir,'profile'),seed:427,now:1794434400000});let serial=0,model;
const go=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);return model=r.model;};
try{
 go('new_career',{mode:'fiction',club:13});settleClubMeetings(model,go);
 const rel=model.clubLife.relationships,event=rel.event;assert.ok(event?.available);
 const player=rel.players.find(p=>p.id===event.playerId);assert.ok(player?.conversationAvailable);
 go('relationship_conversation',{context:rel.context,playerId:player.id,choice:'rassurer'});
 // The other person's different choice must never enter the selected history.
 const other=model.clubLife.relationships.players.find(p=>p.id!==player.id&&p.conversationAvailable);
 go('relationship_conversation',{context:rel.context,playerId:other.id,choice:'clarifier'});
 go('locker_room_decision',{context:rel.context,eventKey:event.key,choice:'responsabiliser'});
 const fixture=path.join(dir,'fixture.json');
 fs.writeFileSync(fixture,JSON.stringify({model,player_id:player.id,trait:player.personality.trait,event_title:event.title}));
 const profile=path.join(model.meta.dataDir,'donnees.json'),before=fs.readFileSync(profile),exported=go('export').meta.exportText;
 const result=spawnSync(sdk,[...(process.env.CD_RELATIONSHIP_MEMORY_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','30','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-relationships-memory.gd')],
  {encoding:'utf8',timeout:90000,env:{...process.env,CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_SELF_TEST:'0',CD_RELATIONSHIP_MEMORY_FIXTURE:fixture,CD_RELATIONSHIP_MEMORY_ARTIFACTS:dir}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),log);console.log(log);console.log('Preuves mémoire vestiaire : '+dir);
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.equal(go('export').meta.exportText,exported,'Consultation sans état sportif ou RNG consommé');assert.deepEqual(fs.readFileSync(profile),before,'Profil conservé octet pour octet');
}finally{b.close();}
