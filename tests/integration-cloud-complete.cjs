'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');

function fixture(t,options={}){
 const dataDir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-cloud-merge-'));
 const settings={dataDir,seed:327,now:1794178800000,...options};
 let bridge=createBridge(settings),serial=0;
 const send=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const good=(command,payload)=>{const result=send(command,payload);assert.equal(result.ok,true,command+': '+result.error);return result.model;};
 const file=path.join(dataDir,'PrototypeGodot','donnees.json');
 const raw=()=>JSON.parse(JSON.parse(fs.readFileSync(file,'utf8')).store['bdt-v1']);
 t.after(()=>{bridge.close();fs.rmSync(dataDir,{recursive:true,force:true});});
 return {send,good,file,raw,restart(){bridge.close();bridge=createBridge(settings);return good('snapshot');}};
}
function talk(model){return model.clubLife.matchTalks.scene;}
function decide(f,model){
 const s=talk(model);assert.ok(s);assert.equal(s.options.length,6);
 return f.good('match_talk_decide',{key:s.key,phase:s.phase,choiceId:s.options[0].id,audience:'group',playerIds:[]});
}
function continueTalk(f,model){const s=talk(model);return f.good('match_talk_continue',{key:s.key,phase:s.phase});}
function playToPost(f,model){
 model=f.good('begin_match');
 assert.equal(talk(model).phase,'pre');
 model=continueTalk(f,decide(f,model));
 for(let n=0;n<50;n++){
  model=f.good('tick',{steps:120});
  const s=talk(model);
  if(s?.phase==='post')return decide(f,model);
  if(s){assert.equal(s.phase,'half');model=continueTalk(f,decide(f,model));}
 }
 assert.fail('Real match did not reach the post-match scene');
}

for(const [mode,club] of [['Top 14',0],['Pro D2',14]]){
 test(mode+' (Monde): debrief confirms the result, preserves its day and closes the week only on Sunday',t=>{
  const f=fixture(t,{dailyCalendar:true});
  let model=settleClubMeetings(f.good('new_career',{mode:'world-champ',club}),f.good);
  while(!model.meta.calendarCadence.matchReady)model=settleClubMeetings(f.good('advance_day',{fromDate:model.meta.calendarToday}),f.good);
  model=playToPost(f,model);
  const day=model.meta.calendarToday,week=model.meta.week,score=model.live.score;
  const post=talk(model),payload={key:post.key,phase:post.phase};
  if(club===0){
   const before=fs.readFileSync(f.file);
   const refused=refuseSavePublication(f.file,()=>f.send('match_talk_continue',payload));
   assert.equal(refused.ok,false);assert.deepEqual(fs.readFileSync(f.file),before);
   assert.equal(talk(f.good('snapshot')).phase,'post');
  }
  model=f.good('match_talk_continue',payload);
  assert.equal(model.meta.calendarToday,day,'Debrief cannot skip the remaining days');
  assert.equal(model.meta.week,week,'Debrief does not pay or simulate a second weekly cycle');
  assert.equal(model.meta.calendarCadence.resultConfirmed,true);
  assert.equal(model.live,null);assert.equal(talk(model),null);
  assert.equal(f.raw().contextualMatch.current,null);
  assert.deepEqual(f.raw().live.score,score);
  if(club===0){
   const receipt=f.good('export').meta.exportText;
   model=f.restart();assert.equal(f.good('export').meta.exportText,receipt);
   const stable=fs.readFileSync(f.file);
   assert.equal(f.send('match_talk_continue',payload).ok,false);
   assert.equal(f.send('finish_round').ok,false);
   assert.deepEqual(fs.readFileSync(f.file),stable);
  }
  while(model.meta.week===week)model=f.good('advance_day',{fromDate:model.meta.calendarToday});
  assert.equal(model.meta.week,week+1);
  assert.equal(f.raw().live,null);
  assert.equal(f.raw().contextualMatch.receipts.filter(r=>r.key===post.key).length,3);
 });
}
