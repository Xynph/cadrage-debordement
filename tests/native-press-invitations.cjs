'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const {test}=require('node:test');
const {createBridge}=require('../native/engine/worker.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');

function openProfile(t){
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'cd-press-invitations-'));
 const dir=path.join(folder,'PrototypeGodot');
 const current=path.join(dir,'donnees.json');
 const backup=path.join(dir,'donnees-precedentes.json');
 const open=()=>createBridge({mandatoryPress:true,dataDir:dir,seed:20261110,now:1700000000000});
 let bridge=open(), sequence=0;
 const send=(command,payload={})=>bridge.handle({id:++sequence,command,payload});
 const good=(command,payload)=>{const result=send(command,payload);assert.equal(result.ok,true,result.error);return result.model;};
 const bytes=()=>[current,backup].map(file=>fs.existsSync(file)?fs.readFileSync(file):null);
 t.after(()=>{
  bridge.close();
  fs.rmSync(folder,{recursive:true,force:true});
 });
 return {send,good,bytes,current,reopen(){
  good('shutdown');
  assert.equal(fs.existsSync(path.join(dir,'profil.lock')),false);
  bridge=open();
  return good('snapshot');
 }};
}
function payload(model,invitationId){
 const press=model.clubLife.press;
 return {context:press.context,answers:press.conference.questions.map(q=>({questionId:q.id,answerId:'r4'})),
  ...(invitationId===undefined?{}:{invitationId})};
}
function sign(doc){
 let sum=2166136261;
 for(const char of JSON.stringify(doc.state).split(''))sum=Math.imul(sum^char.charCodeAt(0),16777619);
 doc.checksum=(sum>>>0).toString(16).padStart(8,'0');
 return JSON.stringify(doc);
}

test('L’invitation presse persiste, refuse un mauvais ID et donne un reçu atomique',t=>{
 const profile=openProfile(t),{good,send,bytes}=profile;
 const initial=good('new_career',{mode:'fiction',club:0});
 const [invitation]=initial.clubLife.press.invitations;
 assert.deepEqual(invitation,{id:'press-v1:1:0:0',context:{season:1,week:0,club:0},kind:'arrival',status:'pending'});
 assert.equal(initial.clubLife.press.conference.invitationId,invitation.id);
 const saved=bytes(), text=good('export').meta.exportText;
 assert.deepEqual(profile.reopen().clubLife.press.invitations,[invitation]);
 assert.equal(good('export').meta.exportText,text);
 assert.deepEqual(bytes(),saved,'Lecture et reprise n’écrivent pas le courrier');
 const malformed=JSON.parse(text);
 malformed.state.pressInvitations.entries[0].id='press-v1:1:1:0';
 const importRefused=send('import',{text:sign(malformed)});
 assert.equal(importRefused.ok,false);
 assert.match(importRefused.error,/invitation/i);
 assert.deepEqual(bytes(),saved);
 const rejected=send('press_conference',payload(initial,'press-v1:1:1:0'));
 assert.equal(rejected.ok,false);
 assert.match(rejected.error,/invitation/i);
 assert.deepEqual(bytes(),saved);

 const refused=refuseSavePublication(profile.current,()=>send('press_conference',payload(initial,invitation.id)));
 assert.equal(refused.ok,false);
 assert.deepEqual(refused.model.clubLife.press.invitations,[invitation]);
 assert.deepEqual(refused.model.clubLife.press.history,[]);
 assert.deepEqual(bytes(),saved);

 const published=good('press_conference',payload(initial,invitation.id));
 const receipt={...invitation,status:'published'};
 assert.deepEqual(published.clubLife.press.invitations,[receipt]);
 assert.equal(published.clubLife.press.lastOutcome.invitationId,invitation.id);
 assert.ok(published.clubLife.press.history.length>=2);
 assert.deepEqual(profile.reopen().clubLife.press.invitations,[receipt]);
 const after=bytes();
 assert.equal(send('press_conference',payload(initial,invitation.id)).ok,false);
 assert.deepEqual(bytes(),after);
 const transfer=openProfile(t);
 assert.deepEqual(transfer.good('import',{text:good('export').meta.exportText}).clubLife.press.invitations,[receipt]);
});

test('Une invitation bloque la progression jusqu’à publication et un direct importé peut finir',t=>{
 const profile=openProfile(t),{good,send,bytes}=profile;
 let model=good('new_career',{mode:'fiction',club:0});
 const [arrival]=model.clubLife.press.invitations;
 assert.equal(model.clubLife.press.conference.required,true);
 const previous=bytes();
 for(const command of ['begin_match','finish_round']){
  const rejected=send(command);
  assert.equal(rejected.ok,false);
  assert.match(rejected.error,/Réception/);
 }
 assert.equal(send('press_conference',payload(model)).ok,false,'Identifiant du courrier exigé');
 assert.deepEqual(bytes(),previous);
 model=settleClubMeetings(good('press_conference',payload(model,arrival.id)),good);
 good('begin_match');

 const live=JSON.parse(good('export').meta.exportText);
 delete live.state.pressInvitations;
 delete live.state.pressConference;
 delete live.state.pressRelations;
 delete live.state.pressPeople;
 model=good('import',{text:sign(live)});
 assert.equal(model.clubLife.press.conference.required,false);
 assert.equal(profile.reopen().clubLife.press.conference.required,false);
 good('delegate');
 model=good('finish_round');
 const [weekly]=model.clubLife.press.invitations;
 assert.equal(weekly.id,'press-v1:1:1:0');
 assert.equal(weekly.kind,'weekly');
 assert.equal(model.clubLife.press.conference.required,true);
 assert.equal(send('press_conference',payload(model,arrival.id)).ok,false);
 model=settleClubMeetings(good('press_conference',payload(model,weekly.id)),good);

 const legacy=JSON.parse(good('export').meta.exportText);
 delete legacy.state.pressInvitations;
 model=good('import',{text:sign(legacy)});
 assert.equal(model.clubLife.press.conference.required,false,'Une conférence déjà publiée par un ancien moteur est reconnue');
 assert.equal(model.clubLife.press.invitations[0].status,'published');
 good('begin_match');
 good('delegate');
 model=good('finish_round');
 assert.equal(model.clubLife.press.invitations[0].id,'press-v1:1:2:0');
 assert.equal(model.clubLife.press.conference.required,true);
});

test('Une reprise de semaine sans agenda recrée une invitation stable',t=>{
 const profile=openProfile(t),{good}=profile;
 good('new_career',{mode:'fiction',club:0});
 const legacy=JSON.parse(good('export').meta.exportText);
 delete legacy.state.pressInvitations;
 const file=JSON.parse(fs.readFileSync(profile.current,'utf8'));
 file.store['bdt-v1']=JSON.stringify(legacy.state);
 fs.writeFileSync(profile.current,JSON.stringify(file));
 const saved=profile.bytes();
 const model=profile.reopen();
 assert.equal(model.clubLife.press.conference.required,true);
 assert.equal(model.clubLife.press.invitations[0].kind,'arrival');
 assert.deepEqual(profile.reopen().clubLife.press.invitations,model.clubLife.press.invitations);
 assert.deepEqual(profile.bytes(),saved);
});

test('Une avance accélérée s’arrête au prochain courrier obligatoire',t=>{
 const {good,send}=openProfile(t);
 const initial=good('new_career',{mode:'world-champ',club:102});
 assert.equal(initial.meta.week,0);
 assert.equal(initial.clubLife.press.invitations[0].kind,'arrival');
 assert.equal(send('advance_champ_preparation',{fromWeek:0}).ok,false);
 settleClubMeetings(good('press_conference',payload(initial,initial.clubLife.press.conference.invitationId)),good);
 const after=good('advance_champ_preparation',{fromWeek:0});
 assert.equal(after.meta.week,1);
 assert.equal(after.clubLife.press.conference.required,true);
 assert.deepEqual(after.clubLife.press.invitations.map(i=>[i.id,i.status]),[
  ['press-v1:1:1:102','pending'],
  ['press-v1:1:0:102','published'],
 ]);
});

test('Le processus JSONL de Godot active l’obligation par défaut',t=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'cd-press-jsonl-'));
 t.after(()=>fs.rmSync(folder,{recursive:true,force:true}));
 const input=[
  {id:1,command:'new_career',payload:{mode:'fiction',club:0}},
  {id:2,command:'begin_match'},
  {id:3,command:'shutdown'}
 ].map(request=>JSON.stringify(request)).join('\n')+'\n';
 const result=spawnSync(process.execPath,[require.resolve('../native/engine/worker.cjs'),'--data-dir',folder],{
  input,encoding:'utf8',timeout:30_000,maxBuffer:16*1024*1024,windowsHide:true
 });
 if(result.error)throw result.error;
 assert.equal(result.status,0,result.stderr);
 const [creation,refusal,shutdown]=result.stdout.trim().split(/\r?\n/).map(line=>JSON.parse(line));
 assert.equal(creation.ok,true);
 assert.equal(creation.model.clubLife.press.conference.required,true);
 assert.equal(refusal.ok,false);
 assert.match(refusal.error,/Réception/);
 assert.equal(refusal.model.live,null);
 assert.equal(shutdown.ok,true);
});
