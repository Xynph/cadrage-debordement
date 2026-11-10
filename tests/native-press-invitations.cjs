'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {test}=require('node:test');
const {createBridge}=require('../native/engine/worker.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');

function openProfile(t){
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'cd-press-invitations-'));
 const dir=path.join(folder,'PrototypeGodot');
 const current=path.join(dir,'donnees.json');
 const backup=path.join(dir,'donnees-precedentes.json');
 const open=()=>createBridge({dataDir:dir,seed:20261110,now:1700000000000});
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

test('Une invitation ignorée ne bloque aucune semaine et les anciennes parties restent ouvertes',t=>{
 const profile=openProfile(t),{good,send,bytes}=profile;
 let model=good('new_career',{mode:'fiction',club:0});
 const [arrival]=model.clubLife.press.invitations;
 good('begin_match');
 good('delegate');
 model=good('finish_round');
 const [first,old]=model.clubLife.press.invitations;
 assert.equal(first.id,'press-v1:1:1:0');
 assert.equal(first.kind,'weekly');
 assert.deepEqual(old,{...arrival,status:'expired'});
 const previous=bytes();
 assert.equal(send('press_conference',payload(model,old.id)).ok,false);
 assert.deepEqual(bytes(),previous);
 model=good('press_conference',payload(model));
 assert.equal(model.clubLife.press.invitations[0].status,'published','La voie presse existante accuse aussi réception');

 const legacy=JSON.parse(good('export').meta.exportText);
 delete legacy.state.pressInvitations;
 model=good('import',{text:sign(legacy)});
 assert.deepEqual(model.clubLife.press.invitations,[]);
 assert.deepEqual(profile.reopen().clubLife.press.invitations,[]);
 assert.equal(JSON.parse(good('export').meta.exportText).state.pressInvitations,undefined);
 good('begin_match');good('delegate');
 model=good('finish_round');
 assert.deepEqual(model.clubLife.press.invitations.map(i=>i.id),['press-v1:1:2:0']);
});

test('L’avance Champ reste groupée et crée le courrier du créneau atteint',t=>{
 const {good}=openProfile(t);
 const initial=good('new_career',{mode:'world-champ',club:102});
 assert.equal(initial.meta.week,0);
 assert.equal(initial.clubLife.press.invitations[0].kind,'arrival');
 const after=good('advance_champ_preparation',{fromWeek:0});
 assert.equal(after.meta.week,4);
 assert.deepEqual(after.clubLife.press.invitations.map(i=>[i.id,i.status]),[
  ['press-v1:1:4:102','pending'],
  ['press-v1:1:0:102','expired'],
 ]);
});
