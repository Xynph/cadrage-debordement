'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const test=require('node:test');
const {spawnSync}=require('node:child_process');
const {createBridge,CHAMP_IMPORT_LIMIT_BYTES,CHAMP_REQUEST_LIMIT_BYTES}=require('../native/engine/worker.cjs');

const MODE='world-champ',DATABASE='rugby-world-2026-11-09-champ-v5';
const CLUBS=Array.from({length:14},(_,i)=>102+i);
const EXPECTED_PLAYABLE=114;
function checksum(state){
 let h=2166136261;
 const text=JSON.stringify(state);
 for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);
 return (h>>>0).toString(16).padStart(8,'0');
}

test('Champ v5 — création, calendrier, worker et sauvegarde',()=>{
 const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-champ-worker-'));
 let serial=0,bridge;
 const open=()=>createBridge({dataDir:root,seed:827381,now:1794178800000});
 const raw=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const go=(command,payload={})=>{
  const reply=raw(command,payload);
  assert.equal(reply.ok,true,command+' · '+reply.model?.meta.week+' : '+reply.error);
  return reply.model;
 };
 const checkpoint=()=>{const text=go('export').meta.exportText;return {text,doc:JSON.parse(text),bytes:Buffer.byteLength(text)};};
 try{
  bridge=open();
  const setup=go('snapshot');
  assert.equal(setup.meta.champDatabase.id,DATABASE);
  assert.equal(setup.meta.champCatalogue.length,116);
  assert.equal(setup.meta.champCatalogue.filter(c=>c.playable).length,EXPECTED_PLAYABLE);
  assert.equal(setup.meta.champPackCreation,'base');
  assert.equal(CHAMP_IMPORT_LIMIT_BYTES,24*1024*1024);
  assert.equal(CHAMP_REQUEST_LIMIT_BYTES,50*1024*1024);
  assert.equal(raw('new_career',{mode:MODE,club:56}).ok,false);
  let model=settleClubMeetings(go('new_career',{mode:MODE,club:102}),(command,payload)=>go(command,payload));
  assert.equal(model.meta.leagueId,'champ');
  assert.equal(model.meta.edition,MODE);
  assert.equal(model.staff.teams.length,116);
  assert.ok(model.staff.teams.find(t=>t.id===102).members.length>0);
  assert.equal(model.calendar.length,26);
  assert.equal(model.meta.champPreparation.nextWeek,4);
  assert.deepEqual(model.champBoundary,{national1:'closed-game-boundary',premExchange:false});
  const initial=checkpoint();
  assert.equal(initial.doc.state.worldMode.fixtures.filter(f=>f.competitionId==='champ').length,182);
  assert.deepEqual(initial.doc.state.worldMode.leagues.champ.members,CLUBS);
  assert.equal(initial.doc.state.worldMode.leagues.nationale.members.length,14);
  assert.equal(initial.doc.state.worldMode.leagues.prem.members.length,10);
  const bad=JSON.parse(initial.text);bad.state.worldMode.champ.premExchange=true;bad.checksum=checksum(bad.state);
  assert.equal(raw('import',{text:JSON.stringify(bad)}).ok,false);
  assert.deepEqual(checkpoint().doc.state,initial.doc.state);
  assert.equal(raw('advance_champ_preparation',{fromWeek:1}).ok,false);
  assert.deepEqual(checkpoint().doc.state,initial.doc.state);
  model=go('advance_champ_preparation',{fromWeek:0});
  assert.equal(model.meta.week,4);
  assert.equal(model.next.competitionId,'champ');
  assert.equal(raw('advance_champ_preparation',{fromWeek:4}).ok,false);
  const full=process.env.CD_WORLD_CHAMP_FULL==='1';
  for(let week=4;week<(full?46:5);week++){
   if(model.next){
    if(!model.selection.valid){
     model=go('auto_lineup');
     if(!model.selection.valid){
      console.log(JSON.stringify({week,cover:model.selection.errors}));
      model=go('promote_cover',{confirmed:true});
     }
     assert.equal(model.selection.valid,true,'feuille Champ à la semaine '+week+': '+model.selection.errors.join(', '));
    }
    go('begin_match');go('delegate');
   }
   model=settleClubMeetings(go('finish_round'),(command,payload)=>go(command,payload));assert.equal(model.meta.week,week+1);
   if([4,20,35,40,45].includes(week)){
    const p=checkpoint();console.log(JSON.stringify({week:week+1,bytes:p.bytes,results:p.doc.state.history.length}));
   }
  }
  const current=checkpoint();
  const state=current.doc.state;
  assert.ok(state.history.some(r=>r.competitionId==='champ'));
  const badLeagueProof=JSON.parse(current.text);
  badLeagueProof.state.history.find(r=>r.competitionId==='champ'&&r.phase==='league').champExtra={version:1};
  badLeagueProof.checksum=checksum(badLeagueProof.state);
  assert.equal(raw('import',{text:JSON.stringify(badLeagueProof)}).ok,false);
  go('shutdown');bridge=open();assert.deepEqual(checkpoint().doc.state,state);
  if(full){
   assert.equal(state.phase,'ended');
   assert.equal(state.history.length,state.worldMode.fixtures.length);
   assert.equal(state.history.filter(r=>r.competitionId==='champ').length,187);
   assert.ok(state.history.length<1600);
   for(const league of ['champ','nationale','prem','jlo-d1','jlo-d2','srp'])assert.ok(Number.isInteger(state.worldMode.leagues[league].champion));
   go('import',{text:current.text});assert.deepEqual(checkpoint().doc.state,state);
   model=settleClubMeetings(go('next_season',{confirmed:true}),(command,payload)=>go(command,payload));assert.equal(model.meta.season,2);
   const s2=checkpoint();
   const yearbook=s2.doc.state.worldMode.yearbook[0];
   assert.equal(yearbook.champions.champ,state.worldMode.leagues.champ.champion);
   assert.equal(yearbook.finalists.champ,state.worldMode.leagues.champ.finalist);
   assert.deepEqual(yearbook.champ,state.worldMode.champ);
   assert.deepEqual(s2.doc.state.worldMode.leagues.champ.members,CLUBS);
   assert.deepEqual(s2.doc.state.worldMode.leagues.prem.members,state.worldMode.leagues.prem.members);
   assert.deepEqual(s2.doc.state.worldMode.leagues.nationale.members,state.worldMode.nationale.movement.nationale);
   assert.equal(s2.doc.state.worldMode.qualification.champions.length,24);
   assert.equal(s2.doc.state.worldMode.qualification.challenge.length,18);
   assert.equal(s2.doc.state.history.length,0);
   assert.equal(s2.doc.state.worldMode.fixtures.filter(f=>f.competitionId==='champ'&&f.scheduleSource==='generated-frozen-format').length,182);
   const badArchive=JSON.parse(s2.text),archive=badArchive.state.worldMode.yearbook[0];
   archive.champions.champ=archive.standings.champ.at(-1);badArchive.checksum=checksum(badArchive.state);
   assert.equal(raw('import',{text:JSON.stringify(badArchive)}).ok,false);
   assert.deepEqual(checkpoint().doc.state,s2.doc.state);
   const over=current.text.padEnd(CHAMP_IMPORT_LIMIT_BYTES+1,' ');
   const requests=[{id:1,command:'import',payload:{text:over}},
    {id:2,command:'import',payload:{text:current.text}},{id:3,command:'shutdown'}];
   const wire=spawnSync(process.execPath,[path.resolve(__dirname,'../native/engine/worker.cjs'),'--data-dir',path.join(root,'wire')],
    {input:requests.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',maxBuffer:64*1024*1024,timeout:120_000});
   assert.equal(wire.status,0,wire.stderr||wire.error?.message);
   const replies=wire.stdout.trim().split('\n').map(x=>JSON.parse(x));
   assert.equal(replies.length,3);
   assert.equal(replies[0].ok,false);assert.match(replies[0].error,/trop volumineux/);
   assert.equal(replies[1].ok,true,replies[1].error);assert.equal(replies[1].model.meta.week,46);
   assert.equal(replies[1].model.meta.edition,MODE);assert.equal(replies[2].ok,true);
   console.log(JSON.stringify({season2:true,bytes:s2.bytes,fixtures:s2.doc.state.worldMode.fixtures.length}));
  }
 }finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
});
