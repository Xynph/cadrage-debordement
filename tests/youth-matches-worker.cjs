'use strict';
// Matchs des jeunes dans le vrai worker : les semaines jouées font avancer le calendrier jeunes,
// la sauvegarde reste valide et identique après réouverture.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict');
const {test}=require('node:test');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');

test('Matchs des jeunes · carrière Base commune, premières semaines',t=>{
 const dataDir=fs.mkdtempSync(path.join(path.resolve(os.tmpdir()),'oval-youth-matches-'));
 const options={dataDir,seed:827381,now:1794178800000};
 let bridge=createBridge(options);
 t.after(()=>{bridge.close();fs.rmSync(dataDir,{recursive:true,force:true});});
 let id=0;
 const ask=(command,payload={})=>bridge.handle({id:++id,command,payload});
 const ok=(command,payload)=>{const r=ask(command,payload);assert.equal(r.ok,true,`${command}: ${r.error}`);return r.model;};
 const go=(command,payload)=>settleClubMeetings(ok(command,payload),ok);
 const state=()=>JSON.parse(ok('export').meta.exportText).state;
 let model=go('new_career',{mode:'common',club:29});
 for(let w=0;w<6&&model.meta.phase!=='ended';w++){
  if(model.next){if(!model.selection.valid){ok('auto_lineup');if(!ok('snapshot').selection.valid)ok('promote_cover',{confirmed:true});}ok('begin_match');ok('delegate');}
  model=go('finish_round');
 }
 const s=state();
 assert.equal(s.youthMatches.season,1);
 assert.ok(s.youthMatches.own.C.length+s.youthMatches.own.E.length>0,'le centre a joué');
 assert.ok(s.development.academy.some(p=>p.youthLoad?.[1]>0));
 assert.ok(s.aiRoster.academies.every(a=>a.players.some(p=>p.youthLoad?.[1]>0)),'tous les centres jouent');
 assert.ok(model.clubLife.youthMatches.available);
 const saved=ok('export').meta.exportText;
 bridge.close();bridge=createBridge(options);
 assert.equal(ok('export').meta.exportText,saved);
 ok('import',{text:saved});
});
