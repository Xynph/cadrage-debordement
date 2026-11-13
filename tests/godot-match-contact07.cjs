'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
const {skipMatchTalk}=require('./helpers/scene-match-talks.cjs');
// Optional capture input from an isolated generated career, never a player save.
// Normal behavioural verification does not need to simulate a match again.
if(process.env.CD_MATCH_CONTACT_PREPARE==='1'){
 const proof=process.env.CD_MATCH_CONTACT_PROOF;
 assert.ok(proof,'CD_MATCH_CONTACT_PROOF required for generated capture input');
 fs.mkdirSync(proof,{recursive:true});
 const {createBridge}=require('../native/engine/worker.cjs');
 const bridge=createBridge({dataDir:path.join(proof,'generated-profile'),seed:62511,now:1700000000000});
 let sequence=0;const call=(command,payload={})=>{const r=bridge.handle({id:++sequence,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
 const lives=[];let previous=null;
 try{
  settleClubMeetings(call('new_career',{mode:'common',club:0}),call);let model=skipMatchTalk(call('begin_match'),call);
  for(let tick=0;tick<50&&lives.length<32&&!model.live.finished;tick++){
   model=skipMatchTalk(model,call);
   if(model.live.scene.key!==previous){lives.push(structuredClone(model.live));previous=model.live.scene.key;}
   model=model.live.paused||model.live.atBreak?call('pause',{paused:false}):call('tick',{steps:1});
  }
 }finally{bridge.close();}
 let best=null;
 lives.forEach((live,index)=>{
  if(!['carry','turnover'].includes(live.scene.kind))return;
  const carrier=live.scene.players.find(p=>p.featured&&p.side===live.scene.possession);if(!carrier)return;
  for(const player of live.scene.players.filter(p=>p.side!==carrier.side)){
   const distance=Math.hypot(carrier.x-player.x,carrier.y-player.y);
   if(!best||distance<best.distance)best={seed:62511,index,distance,kind:live.scene.kind,carrier:carrier.id,opponent:player.id};
  }
 });
 assert.ok(best,'Real carry from native worker required');const index=best.index;
 const selected=lives.slice(Math.max(0,index-3),Math.min(lives.length,index+4));
 fs.writeFileSync(path.join(proof,'real-fragments.json'),JSON.stringify({source:'native/engine/worker.cjs createBridge, generated common career; no personal save',best,lives:selected},null,2));
}
test('Native match: geometric brace preserves presence, limbs, ball and frozen snapshots', {skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const proof=process.env.CD_MATCH_CONTACT_PROOF||fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-contact07-'));
 fs.mkdirSync(proof,{recursive:true});
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--path',process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-contact07.gd')],{encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'contact-headless.log'),output);console.log(output);console.log('Proof: '+proof);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
