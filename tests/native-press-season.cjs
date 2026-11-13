'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_PRESS_TEST_ROOT||require('node:os').tmpdir(),'cd-native-press-season-'));
const open=()=>createBridge({mandatoryPress:true,dataDir:root,seed:399,now:1700000000000});let b=open(),n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const payload=m=>({context:m.clubLife.press.context,invitationId:m.clubLife.press.conference.invitationId,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});
try{
 let m=good('new_career',{mode:'common',club:29}),guard=0;
 while(m.meta.week<34){
  assert.ok(guard++<40);assert.equal(m.clubLife.press.conference.required,true);
  m=good('press_conference',payload(m));assert.equal(m.clubLife.press.lastOutcome.context.week,m.meta.week);
  m=settleClubMeetings(m,good);
  if(m.next){
   if(!m.selection.valid)m=good('auto_lineup');
   if(!m.selection.valid){
    const expectedSlots=m.selection.coverage?.slots;
    assert.ok(expectedSlots?.length,`Semaine ${m.meta.week} : feuille incomplète sans renfort disponible`);
    m=good('promote_cover',{confirmed:true,expectedSlots});
   }
   assert.equal(m.selection.valid,true,'Feuille qualifiée avant la rencontre réelle');
   good('begin_match');good('delegate');
  }
  m=good('finish_round');
 }
 assert.equal(m.meta.week,34);
 assert.equal(m.clubLife.press.invitations[0].kind,'season_review');
 assert.equal(m.clubLife.press.conference.questions[0].theme,'classement');
 const refused=b.handle({id:++n,command:'next_season',payload:{confirmed:true}});
 assert.equal(refused.ok,false);assert.match(refused.error,/Réception/);
 m=good('press_conference',payload(m));assert.equal(m.clubLife.press.lastOutcome.context.week,34);
 const saved=good('export').meta.exportText;good('shutdown');b=open();assert.equal(good('export').meta.exportText,saved);
 m=settleClubMeetings(good('snapshot'),good);m=good('next_season',{confirmed:true});assert.equal(m.clubLife.press.context.season,2);assert.equal(m.clubLife.press.context.week,0);m=good('press_conference',payload(m));assert.equal(m.clubLife.press.lastOutcome.context.season,2);
 const file=path.join(root,'PrototypeGodot','donnees.json');good('shutdown');const doc=JSON.parse(fs.readFileSync(file));const state=JSON.parse(doc.store['bdt-v1']);state.pressConference.version=999;doc.store['bdt-v1']=JSON.stringify(state);fs.writeFileSync(file,JSON.stringify(doc));const hostile=fs.readFileSync(file);b=createBridge({dataDir:root});assert.equal(good('snapshot').meta.recoveryRequired,true);assert.deepEqual(fs.readFileSync(file),hostile,'Profil hostile préservé sans effacement.');
 console.log('Presse saison réelle club29 : conférences obligatoires sur 34 semaines, bilan avant saison 2, reprise et sauvegarde hostile préservée. Profil : '+root);
}finally{b.close();}
