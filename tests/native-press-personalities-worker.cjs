'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-press-personalities-worker-'));let bridge,seq=0;
const open=()=>bridge=createBridge({dataDir:root,seed:13,now:1700000000000});
const call=(command,payload={})=>bridge.handle({id:++seq,command,payload});
const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const exported=()=>good('export').meta.exportText;
const choose=m=>({context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r4'}))});
function sign(doc){let h=2166136261;const raw=JSON.stringify(doc.state);for(let i=0;i<raw.length;i++)h=Math.imul(h^raw.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 open();let m=good('new_career',{mode:'common',club:0}),before=exported(),disk=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(disk);
 for(let i=0;i<3;i++)good('snapshot');assert.equal(exported(),before);assert.deepEqual(fs.readFileSync(disk),bytes);assert.equal(JSON.parse(before).state.pressPeople,undefined);
 const asked=m.clubLife.press.conference.questions;m=good('press_conference',choose(m));
 for(const q of asked){const h=m.clubLife.press.history.find(h=>h.id===q.id);assert.equal(h.question,q.question);assert.equal(h.answer,q.answers[4].text);assert.deepEqual(h.journalist,{id:q.journalist.id,name:q.journalist.name,outlet:q.journalist.outlet});const person=m.clubLife.press.people.find(j=>j.id===q.journalist.id);assert.equal(person.encounters,1);assert.equal(person.memory[0].answer,q.answers[4].text);}
 const exact=exported(),people=m.clubLife.press.people;good('import',{text:exact});good('shutdown');bridge.close();open();assert.equal(exported(),exact);assert.deepEqual(good('snapshot').clubLife.press.people,people);
 for(const corrupt of [s=>s.pressPeople.version=2,s=>s.pressPeople.contacts.unknown={score:0,encounters:1,memory:[]},s=>s.pressPeople.contacts[asked[0].journalist.id].memory[0].answerId='r9',s=>s.pressPeople.contacts[asked[0].journalist.id].encounters=0,s=>s.pressPeople.contacts[asked[0].journalist.id].memory[0].secret='x']){const d=JSON.parse(exact);corrupt(d.state);assert.equal(call('import',{text:sign(d)}).ok,false);assert.equal(exported(),exact);}
 const legacy=JSON.parse(exact);delete legacy.state.pressPeople;for(const h of legacy.state.pressConference.history){delete h.journalist;delete h.questionText;delete h.answerText;h.answerId='r3';}delete legacy.state.pressConference.lastOutcome.exchanges;m=good('import',{text:sign(legacy)});assert.ok(m.clubLife.press.people.every(j=>!j.encounters));assert.ok(m.clubLife.press.history.every(h=>h.question===null&&h.answer===null&&!h.journalist));good('import',{text:exact});
 // Real full-calendar play, then an actual manager move. No fabricated past matches.
 m=settleClubMeetings(good('snapshot'),good);m=good('manager_career_activate',{context:good('snapshot').clubLife.managerCareer.context});
 for(let i=0;i<34;i++){
  m=good('snapshot');if(m.clubLife.press.conference.available)good('press_conference',choose(m));
  m=settleClubMeetings(good('snapshot'),good);if(m.next){good('begin_match');good('delegate');}m=good('finish_round');
 }
 assert.equal(m.clubLife.press.context.week,34);m=good('press_conference',choose(m));
 m=settleClubMeetings(m,good);const c=m.clubLife.managerCareer,target=c.opportunities.find(o=>o.clubId>=14&&o.accepted);assert.ok(target);
 good('manager_career_apply',{context:c.context,clubId:target.clubId});good('manager_career_accept',{context:c.context,offerId:'job-1-'+target.clubId,confirmed:true});
 const memoryBefore=JSON.parse(exported()).state.pressPeople;m=good('next_season',{confirmed:true});assert.equal(JSON.parse(exported()).state.club,target.clubId);assert.deepEqual(JSON.parse(exported()).state.pressPeople,memoryBefore,'Mémoire du coach conservée lors de la vraie mobilité');
 const payload=choose(m),rollback=exported(),prior=fs.readFileSync(disk);
 const refused=refuseSavePublication(disk,()=>call('press_conference',payload));
 assert.equal(refused.ok,false);assert.match(refused.error,/sauvegarde impossible/);
 assert.equal(exported(),rollback);assert.deepEqual(fs.readFileSync(disk),prior);m=good('press_conference',payload);
 const namespace=JSON.parse(exported()).state.pressPeople;assert.ok(Buffer.byteLength(JSON.stringify(namespace))<30000);assert.ok(Object.values(namespace.contacts).every(c=>c.memory.length<=3));
 // The worst supported contact count remains compact; these are explicit test exchanges.
 const bank=require('../dist/press-question-bank.js'),relations=require('../dist/press-relations.js');let full;
 for(const j of bank.journalists)for(let week=0;week<3;week++)full=relations.recordDialogue(full,j,{season:1,week,club:0,questionId:'avant_match-0-'+week,answerId:'r4'},1);
 assert.equal(Object.keys(full.contacts).length,bank.journalists.length);assert.ok(Buffer.byteLength(JSON.stringify(full))<1000*bank.journalists.length);
 console.log('Personnalités vrai worker PASS : 5 choix, archives exactes, import/reprise, legacy, état hostile, France34, vraie mobilité Élite→Accession, rollback, budget30contacts='+Buffer.byteLength(JSON.stringify(full))+' octets ; profil '+root);
}finally{bridge?.close();}
