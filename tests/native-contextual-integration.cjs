'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
// Integration contract: use the exported production worker, its real VM, match
// simulation, validation and atomic filesystem publication. No source rewriting.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createBridge} = require('../native/engine/worker.cjs');
const {refuseSavePublication} = require('./helpers/save-publication-refusal.cjs');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-contextual-qa-'));
  let bridge = createBridge({dataDir:directory, seed:13, now:1700000000000}), sequence = 0;
  const send = (command, payload={}) => bridge.handle({id:++sequence, command, payload});
  const good = (command, payload={}) => {
    const response = send(command, payload);
    assert.equal(response.ok, true, command+': '+response.error);
    return response.model;
  };
  const file = path.join(directory, 'PrototypeGodot/donnees.json');
  const exported = () => good('export').meta.exportText;
  const bytes = () => fs.readFileSync(file);
  const state = () => JSON.parse(exported()).state;
  const checkpoint = () => ({text:exported(), bytes:bytes()});
  const exact = before => {
    assert.equal(exported(), before.text, 'Refusal/read preserves career, receipts, RNG and clock');
    assert.deepEqual(bytes(), before.bytes, 'Primary save preserved byte for byte');
  };
  const bad = (command,payload={}) => {
    const before = checkpoint(), response = send(command,payload);
    assert.equal(response.ok,false,command+' must refuse '+JSON.stringify(payload));
    assert.ok(response.error, 'Refusal has a visible reason');
    exact(before); return response;
  };
  const reopen = () => {
    const before = checkpoint(); bridge.close();
    bridge = createBridge({dataDir:directory, seed:999, now:1});
    exact(before); return good('snapshot');
  };
  t.after(() => {bridge.close();fs.rmSync(directory,{recursive:true,force:true});});
  settleClubMeetings(good('new_career',{mode:'common',club:29}),good);
  return {send,good,bad,exported,bytes,state,file,checkpoint,exact,reopen};
}

function editDocument(text, mutate) {
  const document = JSON.parse(text); mutate(document.state);
  const body = JSON.stringify(document.state); let checksum = 2166136261;
  for (let i=0;i<body.length;i++) checksum = Math.imul(checksum^body.charCodeAt(i),16777619);
  document.checksum = (checksum>>>0).toString(16).padStart(8,'0');
  return JSON.stringify(document);
}
const talks = model => {
  assert.ok(model.clubLife.matchTalks, 'matchTalks is registered in the real model');
  return model.clubLife.matchTalks;
};
const invitations = model => {
  assert.ok(model.clubLife.sceneInvitations, 'sceneInvitations is registered in the real model');
  return model.clubLife.sceneInvitations;
};
function scene(f,phase) {
  const model=f.good('snapshot'), value=talks(model).scene;
  assert.ok(value,'Pending '+phase+' scene'); assert.equal(value.phase,phase);
  assert.equal(value.options.length,6,'Exactly six declarations');
  assert.equal(new Set(value.options.map(o=>o.id)).size,6);
  for (const option of value.options) {
    assert.ok(option.text.length>0&&option.text.length<=120,'Short original declaration: '+option.id);
    assert.ok(option.tone&&option.intent,'Intrinsic tone and intention are supplied');
  }
  const state=f.state(), sheet=state.live.sheets[state.live.userSide];
  assert.deepEqual(value.participants.map(p=>p.id), [...sheet.initial,...sheet.bench]);
  assert.equal(value.participants.length,23);
  assert.equal(new Set(value.participants.map(p=>p.id)).size,23);
  assert.ok(value.participants.every(p=>state.clubs[state.club].players.some(q=>q.id===p.id)), 'Participants belong to the actual active roster');
  const before=f.checkpoint(); f.good('snapshot'); f.good('snapshot'); f.exact(before);
  return value;
}
function start(f) { settleClubMeetings(f.good('snapshot'),(command,payload)=>f.good(command,payload));settleClubMeetings(f.good('train'),(command,payload)=>f.good(command,payload)); f.good('auto_lineup'); return f.good('begin_match'); }
function continueScene(f,s,skip=false) {return f.good('match_talk_continue',{key:s.key,phase:s.phase,...(skip?{skip:true}:{})});}
function decidePayload(s) {return {key:s.key,phase:s.phase,choiceId:s.options[0].id,audience:'players',playerIds:[s.participants[0].id]};}
function boundary(f,phase) {
  let model;
  for(let batches=0;batches<40;batches++) {
    model=f.good('tick',{steps:120});
    if(talks(model).scene) {assert.equal(talks(model).scene.phase,phase); return model;}
  }
  assert.fail('Actual simulation did not reach '+phase+' within 4800 steps');
}
function assertGuards(f,s) {
  if(s.phase!=='post') {f.bad('tick',{steps:120});f.bad('pause',{paused:false});}
  f.bad('finish_round');
  f.bad('match_talk_continue',{key:s.key,phase:s.phase});
}
function publicationRefusal(f,command,payload) {
  const before=f.checkpoint();
  const response=refuseSavePublication(f.file,()=>f.send(command,payload));
  assert.equal(response.ok,false,'Real publication failure refuses '+command);
  assert.match(response.error,/sauvegarde|refus|publication|écri/i);
  f.exact(before);
}

test('Contextual invitations: real people, pure reads, one atomic answer and explicit close',t=>{
  const f=fixture(t), initial=invitations(f.good('snapshot')), state=f.state();
  const player=initial.invitations.find(e=>e.kind==='private_player');
  const staff=initial.invitations.find(e=>e.kind==='private_staff');
  assert.ok(player&&staff,'New career introduces an actual player and current staff member');
  assert.ok(state.clubs[29].players.some(p=>p.id===player.participantId));
  const before=f.checkpoint();f.good('snapshot');f.good('snapshot');f.exact(before);
  f.bad('scene_invitation_open',{id:player.id,unexpected:true});
  publicationRefusal(f,'scene_invitation_open',{id:player.id});
  let active=invitations(f.good('scene_invitation_open',{id:player.id})).active;
  assert.equal(active.id,player.id);assert.equal(active.options.length,3,'Private interviews offer three focused replies; collective match talks offer six');
  const opened=f.checkpoint(); f.reopen(); f.exact(opened);
  settleClubMeetings(f.good('train'),(command,payload)=>f.good(command,payload));f.good('auto_lineup');f.bad('begin_match');
  f.bad('scene_invitation_open',{id:staff.id});
  f.bad('scene_invitation_reply',{id:player.id,choiceId:'not-offered'});
  const payload={id:player.id,choiceId:active.options[0].id};
  publicationRefusal(f,'scene_invitation_reply',payload);
  active=invitations(f.good('scene_invitation_reply',payload)).active;
  assert.equal(active.decision.choiceId,payload.choiceId);
  assert.equal(active.decision.effect,'relationship');
  const answered=f.checkpoint();f.reopen();f.exact(answered);
  f.bad('scene_invitation_reply',payload);
  publicationRefusal(f,'scene_invitation_close',{id:player.id});
  const closed=invitations(f.good('scene_invitation_close',{id:player.id}));
  assert.equal(closed.active,null);assert.equal(closed.history.filter(e=>e.id===player.id).length,1);
  assert.equal(closed.invitations.find(e=>e.id===player.id).status,'completed');
  f.bad('scene_invitation_open',{id:player.id});f.bad('scene_invitation_reply',payload);
  const prior=f.checkpoint();f.good('snapshot');f.exact(prior);
  // The remaining unopened invitation expires at the real kickoff.
  f.good('begin_match');
  assert.equal(invitations(f.good('snapshot')).invitations.find(e=>e.id===staff.id).status,'expired');
  f.bad('scene_invitation_open',{id:staff.id});
});

test('Three real match phases: batched boundaries, restart, intrinsic decisions and once-only round commit',t=>{
  const f=fixture(t);let model=start(f), s=scene(f,'pre');
  assert.equal(model.live.minute,0);assert.equal(model.live.paused,true);
  assertGuards(f,s);
  const payload=decidePayload(s);
  for(const patch of [{tone:'warm'},{phase:'invalid'},{key:s.key+':stale'},{choiceId:'not-offered'},{playerIds:[payload.playerIds[0],payload.playerIds[0]]},{playerIds:['not-in-sheet']},{audience:'leaders'}]) f.bad('match_talk_decide',{...payload,...patch});
  publicationRefusal(f,'match_talk_decide',payload);
  model=f.good('match_talk_decide',payload);
  assert.equal(talks(model).scene.decision.tone,s.options[0].tone);
  assert.deepEqual(talks(model).scene.decision.playerIds,payload.playerIds);
  assert.equal(talks(model).scene.decision.reactions.length,1);
  f.bad('match_talk_decide',payload);
  const decided=f.checkpoint(); f.reopen();f.exact(decided);
  assert.equal(talks(f.good('snapshot')).scene.decision.choiceId,payload.choiceId);
  publicationRefusal(f,'match_talk_continue',{key:s.key,phase:'pre'});
  model=continueScene(f,s);assert.equal(model.live.paused,false);assert.equal(talks(model).scene,null);
  f.bad('match_talk_continue',{key:s.key,phase:'pre',skip:true});
  model=boundary(f,'half'); assert.equal(model.live.atBreak,true);assert.equal(model.live.finished,false);assert.ok(model.live.minute>=40,'Do not fabricate the break at minute 40');
  s=scene(f,'half');assertGuards(f,s);f.reopen();
  f.bad('match_talk_decide',payload);
  model=continueScene(f,s,true);assert.equal(model.live.atBreak,false);assert.equal(model.live.paused,false);
  model=boundary(f,'post');assert.equal(model.live.finished,true);
  s=scene(f,'post');assertGuards(f,s);f.reopen();
  assert.equal(talks(f.good('snapshot')).receipts.length,2);
  const post=decidePayload(s);f.good('match_talk_decide',post);f.reopen();f.bad('match_talk_decide',post);
  const before=f.state(), history=before.history.filter(r=>r.pair?.includes(before.club)).length;
  publicationRefusal(f,'match_talk_continue',{key:s.key,phase:'post'});
  model=continueScene(f,s);assert.equal(model.live,null);assert.equal(talks(model).scene,null);
  const after=f.state();assert.equal(after.economy.week,before.economy.week+1);
  assert.equal(after.history.filter(r=>r.pair?.includes(after.club)).length,history+1);
  assert.deepEqual(talks(model).receipts.map(r=>r.status),['decided','skipped','decided']);
  f.bad('match_talk_continue',{key:s.key,phase:'post',skip:true});f.bad('finish_round');
  f.reopen();
});

test('Delegation skips pending pre/half/post scenes and preserves existing delegate then finish_round workflow',t=>{
  const f=fixture(t);start(f);
  const pre=f.exported();continueScene(f,scene(f,'pre'),true);boundary(f,'half');
  const half=f.exported();continueScene(f,scene(f,'half'),true);boundary(f,'post');
  const post=f.exported();
  for(const [phase,text,expected] of [['pre',pre,['delegated','delegated','delegated']],['half',half,['skipped','delegated','delegated']],['post',post,['skipped','skipped','delegated']]]) {
    f.good('import',{text});
    publicationRefusal(f,'delegate',{});
    const model=f.good('delegate');assert.equal(model.live.finished,true,phase+' delegation completes actual live');
    assert.equal(talks(model).scene,null,phase+' delegation closes every phase');
    assert.deepEqual(talks(model).receipts.map(r=>r.status),expected);
    const before=f.state(), done=settleClubMeetings(f.good('finish_round'),(command,payload)=>f.good(command,payload));assert.equal(done.live,null);
    assert.equal(f.state().economy.week,before.economy.week+1);
    f.bad('finish_round');
  }
});

test('Closed imported namespaces refuse malformed fields atomically; absent old live namespaces stay absent',t=>{
  const f=fixture(t);start(f);const text=f.exported();
  for(const mutate of [s=>s.contextualMatch.version=99,s=>s.contextualMatch.extra=true,s=>s.contextualMatch.current.participants[1].id=s.contextualMatch.current.participants[0].id,s=>s.contextualMatch.current.phases[0].phase='half',s=>s.sceneInvitations.version=99,s=>s.sceneInvitations.invitations[0].extra=true,s=>s.sceneInvitations.activeId='unknown']) {
    f.bad('import',{text:editDocument(text,mutate)});
  }
  const old=editDocument(text,s=>{delete s.contextualMatch;delete s.sceneInvitations;s.live.paused=true;});
  f.good('import',{text:old});
  assert.equal(f.exported(),old,'Old import is not silently migrated by a read');
  f.reopen();assert.equal(talks(f.good('snapshot')).scene,null);
  assert.equal(f.state().contextualMatch,undefined);assert.equal(f.state().sceneInvitations,undefined);
  f.good('tick',{steps:120});assert.equal(talks(f.good('snapshot')).scene,null,'No retroactive pre-match after imported live advances');
  assert.equal(f.state().contextualMatch,undefined);
  f.good('delegate');settleClubMeetings(f.good('finish_round'),(command,payload)=>f.good(command,payload));
});

test('Invitation context is revalidated after club change, participant departure and elapsed window',t=>{
  const f=fixture(t), first=invitations(f.good('snapshot')).invitations.find(e=>e.kind==='private_player');
  const base=f.exported();
  const initial=f.good('snapshot'), colleague=invitations(initial).invitations.find(e=>e.kind==='private_staff');
  const released=f.good('staff_release',{context:initial.clubLife.staffCareer.context,confirmed:true,staffId:colleague.participantId});
  assert.equal(invitations(released).invitations.find(e=>e.id===colleague.id).status,'expired','Actual staff departure expires the invitation on the same mutation');
  f.bad('scene_invitation_open',{id:colleague.id});
  // A genuine new active-club state receives the former club's retained history
  // at the save boundary. This exercises revalidation, without simulating a
  // manager mobility season or fabricating a sporting result.
  settleClubMeetings(f.good('new_career',{mode:'common',club:28}),(command,payload)=>f.good(command,payload));
  const former=JSON.parse(base).state.sceneInvitations;
  f.good('import',{text:editDocument(f.exported(),s=>s.sceneInvitations=former)});
  assert.equal(f.state().club,28);
  for(const entry of invitations(f.good('snapshot')).invitations){assert.equal(entry.available,false);f.bad('scene_invitation_open',{id:entry.id});}
  // These are save-boundary fixtures, not invented invitation IDs. Sport events
  // and receipts stay untouched; all refusals still traverse the real importer.
  for(const [name,mutate] of [
    ['participant',s=>{const e=s.sceneInvitations.invitations.find(e=>e.id===first.id);e.participantId='departed-person-contextual-qa';}],
    ['window',s=>{const e=s.sceneInvitations.invitations.find(e=>e.id===first.id);s.economy.week=e.expires.week;}]
  ]) {
    f.good('import',{text:editDocument(base,mutate)});
    const entries=invitations(f.good('snapshot')).invitations;
    const target=entries.find(e=>e.id===first.id);
    assert.equal(target.available,false,name+' invitation is visibly unavailable');
    f.bad('scene_invitation_open',{id:target.id});
  }
});
