'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {advanceToNextMatch}=require('./helpers/monde-matchs.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');

const loaded={exports:require('../native/engine/worker.cjs')};
const root=fs.mkdtempSync(path.join(process.env.CD_PRESS_TEST_ROOT||require('node:os').tmpdir(),'cd-native-press-'));let b,n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const bad=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,false,command+' doit être refusé');return r;};
const answers=m=>({context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r0'}))});
try{
 b=loaded.exports.createBridge({dataDir:root,seed:398,now:1700000000000});let m=good('new_career',{mode:'world-champ',club:29});
 assert.ok(m.clubLife?.press,'Le vrai worker doit publier la projection presse.');
 let text=good('export').meta.exportText;const file=path.join(root,'PrototypeGodot','donnees.json'),bytes=fs.readFileSync(file);
 for(let i=0;i<4;i++)good('snapshot');assert.equal(good('export').meta.exportText,text);assert.deepEqual(fs.readFileSync(file),bytes);
 const payload=answers(m);bad('press_conference',{...payload,context:{...payload.context,week:1}});assert.equal(good('export').meta.exportText,text);
 const before=m.clubLife.press.metrics;m=good('press_conference',payload);assert.ok(m.clubLife.press.metrics.morale>before.morale);assert.ok(m.clubLife.press.metrics.trust<before.trust);assert.ok(m.clubLife.press.lastOutcome);assert.equal(m.clubLife.press.conference.available,false);
 text=good('export').meta.exportText;bad('press_conference',payload);assert.equal(good('export').meta.exportText,text);
 good('shutdown');b=loaded.exports.createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,text,'Reprise exacte des namespaces presse.');
 good('import',{text});assert.equal(good('export').meta.exportText,text,'Import/export presse exact.');
 for(const alter of [s=>s.pressConference.version=999,s=>s.pressConference.history[0].week=35,s=>s.pressRelations.mediaTrust=-1,s=>s.pressRelations.history=[{}]]){const doc=JSON.parse(text);alter(doc.state);const r=bad('import',{text:JSON.stringify(doc)});assert.match(r.error,/presse|conférence/i);assert.equal(good('export').meta.exportText,text);}
 m=advanceToNextMatch(good('snapshot'),good);good('begin_match');bad('press_conference',payload);good('delegate');m=good('finish_round');const second=answers(m);
 text=good('export').meta.exportText;const priorFile=fs.readFileSync(file);
 const refused=refuseSavePublication(file,()=>bad('press_conference',second));
 assert.match(refused.error,/sauvegarde impossible/);
 assert.equal(good('export').meta.exportText,text,'Rollback complet après refus disque.');assert.deepEqual(fs.readFileSync(file),priorFile);
 m=good('press_conference',second);assert.equal(m.clubLife.press.lastOutcome.context.week,second.context.week);
 good('shutdown');b=loaded.exports.createBridge({dataDir:root,now:1700000000000});assert.equal(good('snapshot').clubLife.press.history.length,m.clubLife.press.history.length);
 console.log('Presse vrai worker '+'intégré'+' : effets, doublon, contexte, live, lecture pure, import/export, reprise et rollback disque PASS. Profils : '+root);
}finally{b?.close();}

