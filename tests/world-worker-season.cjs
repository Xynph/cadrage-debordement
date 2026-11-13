'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-world-season-'));
let serial=0;const started=Date.now(),name=path.join(root,'elite');let b;
const reception=process.env.CD_WORLD_RECEPTION_DIR;
if(reception){assert.ok(path.isAbsolute(reception)&&!fs.existsSync(reception),'fresh explicit receipt directory');fs.mkdirSync(reception);}
let euroExported=false;
function open(){return createBridge({dataDir:name,seed:827381,now:1794178800000});}
function go(command,payload={}){const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+' @ week '+r.model?.meta.week+': '+r.error);return r.model;}
function checkpoint(label){const text=go('export').meta.exportText;return {label,bytes:Buffer.byteLength(text),text,state:JSON.parse(text).state};}
try{
 b=open();let model=settleClubMeetings(go('new_career',{mode:'world',club:0}),(command,payload)=>go(command,payload));const measures=[],played=new Set();
 for(let week=0;week<46;week++){
  if(model.next){played.add(model.next.competitionId);if(reception&&!euroExported&&model.next.competitionId==='champions'){fs.writeFileSync(path.join(reception,'avant-europe.json'),checkpoint('before Europe').text,{flag:'wx'});euroExported=true;}if(!model.selection.valid){go('auto_lineup');if(!go('snapshot').selection.valid)go('promote_cover',{confirmed:true});}go('begin_match');go('delegate');}
  model=settleClubMeetings(go('finish_round'),(command,payload)=>go(command,payload));assert.equal(model.meta.week,week+1);
  if([7,20,33,45].includes(week)){const p=checkpoint('S1W'+(week+1));measures.push([p.label,p.bytes]);console.log(JSON.stringify({checkpoint:p.label,bytes:p.bytes,results:p.state.history.length,elapsedMs:Date.now()-started}));}
  if(week===20){const p=checkpoint('restart');go('shutdown');b=open();assert.deepEqual(checkpoint('reopened').state,p.state);model=go('snapshot');}
 }
 assert.ok(played.has('elite')&&played.has('champions'),'same human club plays league and Europe');
 const final=checkpoint('end');assert.equal(final.state.phase,'ended');assert.ok(final.state.worldMode.movement.promoted.length>=1);
 if(reception){assert.ok(euroExported);fs.writeFileSync(path.join(reception,'fin-saison-1.json'),final.text,{flag:'wx'});}
 for(const id of ['elite','accession','prem','urc'])assert.ok(Number.isInteger(final.state.worldMode.leagues[id].champion),id+' champion');
 for(const id of ['champions','challenge'])assert.ok(Number.isInteger(final.state.worldMode.europe[id].champion),id+' champion');
 assert.equal(final.state.history.filter(r=>r.competitionId==='access').length,1);
 const knockoutRefusals=require('./world-save-runtime.cjs').assertWorldKnockoutImports((command,payload={})=>b.handle({id:++serial,command,payload}),final.text);
 assert.equal(knockoutRefusals,4,'forged knockout score, decision, winner and phase are rejected atomically');
 go('import',{text:final.text});assert.deepEqual(checkpoint('imported').state,final.state);
 model=settleClubMeetings(go('next_season',{confirmed:true}),(command,payload)=>go(command,payload));assert.equal(model.meta.season,2);const second=checkpoint('S2W0');measures.push([second.label,second.bytes]);
 assert.deepEqual(second.state.worldMode.leagues.elite.members,final.state.worldMode.movement.elite);
 assert.equal(second.state.worldMode.qualification.champions.length,24);assert.equal(second.state.worldMode.qualification.challenge.length,18);
 assert.notDeepEqual(second.state.worldMode.europe.champions.pools,final.state.worldMode.europe.champions.pools);
 assert.equal(second.state.history.length,0);assert.equal(second.state.worldMode.yearbook.length,1);
 const archiveRefusals=require('./world-save-runtime.cjs').assertWorldArchiveImports((command,payload={})=>b.handle({id:++serial,command,payload}),second.text);assert.equal(archiveRefusals,2);
 assert.ok(second.state.clubs.flatMap(c=>c.players).some(p=>p.worldRatingsVersion===1&&p.dev.lastYear===1),'annual foreign development executed');
 console.log(JSON.stringify({passed:true,played:[...played],results:final.state.history.length,knockoutRefusals,archiveRefusals,measures,elapsedMs:Date.now()-started}));
}finally{if(b)b.close();fs.rmSync(root,{recursive:true,force:true});}
