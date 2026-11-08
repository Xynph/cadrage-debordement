'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_PRESS_TEST_ROOT||require('node:os').tmpdir(),'cd-native-press-season-'));let b=createBridge({dataDir:root,seed:399,now:1700000000000}),n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const payload=m=>({context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});
try{
 let m=good('new_career',{mode:'common',club:29}),guard=0;
 while(m.meta.week<34){assert.ok(guard++<40);if(m.meta.week>=26){const p=payload(m);m=good('press_conference',p);assert.equal(m.clubLife.press.lastOutcome.context.week,m.meta.week);}
  if(m.next){m=good('begin_match');good('delegate');}m=good('finish_round');
 }
 assert.equal(m.meta.week,34);m=good('press_conference',payload(m));assert.equal(m.clubLife.press.lastOutcome.context.week,34);
 const saved=good('export').meta.exportText;good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,saved);
 m=good('next_season',{confirmed:true});assert.equal(m.clubLife.press.context.season,2);assert.equal(m.clubLife.press.context.week,0);m=good('press_conference',payload(m));assert.equal(m.clubLife.press.lastOutcome.context.season,2);
 const file=path.join(root,'PrototypeGodot','donnees.json');good('shutdown');const doc=JSON.parse(fs.readFileSync(file));const state=JSON.parse(doc.store['bdt-v1']);state.pressConference.version=999;doc.store['bdt-v1']=JSON.stringify(state);fs.writeFileSync(file,JSON.stringify(doc));const hostile=fs.readFileSync(file);b=createBridge({dataDir:root});assert.equal(good('snapshot').meta.recoveryRequired,true);assert.deepEqual(fs.readFileSync(file),hostile,'Profil hostile préservé sans effacement.');
 console.log('Presse saison réelle club29 : conférences26–34, reprise34, saison2 et démarrage hostile préservé PASS. Profils : '+root);
}finally{b.close();}
