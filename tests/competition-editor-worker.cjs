'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
function fixture(t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-calendar-workshop-'));
 let bridge=createBridge({dataDir:dir,seed:827381,now:1794178800000}),serial=0;
 t.after(()=>{bridge.close();fs.rmSync(dir,{recursive:true,force:true});});
 const send=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const good=(command,payload)=>{const r=send(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 return {send,good,bytes:()=>fs.readFileSync(path.join(dir,'PrototypeGodot','donnees.json')),restart:()=>{bridge.close();bridge=createBridge({dataDir:dir,seed:1,now:10});}};
}
const request={action:'generate',name:'Ma ligue',clubs:['Les Aigles','Les Lions','Les Loups'],doubleRound:true};
test('Atelier accessible avant création de carrière, document vérifiable sans mutation',t=>{
 const f=fixture(t),before=f.good('snapshot');
 const result=f.good('competition_editor_preview',request).competitionEditor;
 assert.equal(result.summary.matches,6);assert.equal(result.summary.rounds,6);assert.equal(result.summary.byesPerClub,2);
 assert.match(result.notice,/autres restent des documents échangeables/);
 assert.deepEqual(f.good('snapshot'),before,'le brouillon ne persiste pas dans le modèle');
 const validated=f.good('competition_editor_preview',{action:'validate',document:JSON.parse(result.exportText)}).competitionEditor;
 assert.deepEqual(validated,result);
 const bad=structuredClone(result.document);bad.fixtures[0].awayId=bad.fixtures[0].homeId;
 assert.equal(f.send('competition_editor_preview',{action:'validate',document:bad}).ok,false);
 assert.deepEqual(f.good('snapshot'),before);
});
test('Une carrière, son export, son disque et sa reprise restent exactement identiques',t=>{
 const f=fixture(t);settleClubMeetings(f.good('new_career',{mode:'world',club:0}),(command,payload)=>f.good(command,payload));
 const before=f.good('export').meta.exportText,bytes=f.bytes();
 f.good('competition_editor_preview',request);
 assert.equal(f.send('competition_editor_preview',{action:'validate',document:{}}).ok,false);
 assert.equal(f.good('export').meta.exportText,before);assert.deepEqual(f.bytes(),bytes);
 f.restart();assert.equal(f.good('export').meta.exportText,before);
});
