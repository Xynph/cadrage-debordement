'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-academy-worker-'));let id=0;const bridges=[];
function open(name){const b=createBridge({dataDir:path.join(root,name),seed:13,now:1700000000000});bridges.push(b);return b;}
function call(b,command,payload={}){return b.handle({id:++id,command,payload});}function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,r.error);return r.model;}
function execute(b,command,payload={}){const d=good(b,'snapshot').clubLife.academyPathways;return good(b,command,{...d.context,...payload});}
try{
 for(const club of [0,29]){let b=open('club-'+club);settleClubMeetings(good(b,'new_career',{mode:'common',club}),(command,payload)=>good(b,command,payload));const old=good(b,'export').meta.exportText;good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,old);execute(b,'academy_activate',{confirmed:true});let data=good(b,'snapshot').clubLife.academyPathways;assert.equal(data.centerId,'club:'+club);execute(b,'academy_scout',{confirmed:true});execute(b,'academy_path',{playerId:data.players[0].id,strategy:'progression'});
 const current=good(b,'export').meta.exportText;good(b,'import',{text:current});assert.equal(good(b,'export').meta.exportText,current,'import/export exact');good(b,'shutdown');b=open('club-'+club);assert.equal(good(b,'snapshot').meta.recoveryRequired,false);assert.equal(good(b,'export').meta.exportText,current,'reprise exacte');
 const original=JSON.parse(current),hostile=structuredClone(original);hostile.state.nativeAcademy.version=999;assert.equal(call(b,'import',{text:JSON.stringify(hostile)}).ok,false);assert.equal(good(b,'export').meta.exportText,current);
 const dataDir=good(b,'snapshot').meta.dataDir,file=path.join(dataDir,'donnees.json'),disk=fs.readFileSync(file);fs.renameSync(file,file+'.held');fs.mkdirSync(file);const ctx=good(b,'snapshot').clubLife.academyPathways.context,failed=call(b,'academy_mentor',{...ctx,playerId:data.players[0].id,focus:'technique',confirmed:true});assert.equal(failed.ok,false);assert.match(failed.error,/sauvegarde|Écriture/);assert.equal(good(b,'export').meta.exportText,current,'rollback état après panne disque');fs.rmdirSync(file);fs.renameSync(file+'.held',file);assert.deepEqual(fs.readFileSync(file),disk);execute(b,'academy_mentor',{playerId:data.players[0].id,focus:'technique',confirmed:true});settleClubMeetings(good(b,'train'),(command,payload)=>good(b,command,payload));assert.equal(good(b,'snapshot').clubLife.academyPathways.weekMentored,true);
 }
 console.log('PASS vrai worker formation : clubs0/29, import/export, reprise, anciennes carrières, version hostile, coût et rollback disque');
}finally{for(const b of bridges)b.close();}
