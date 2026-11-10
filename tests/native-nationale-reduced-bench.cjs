'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {createBridge}=require('../native/engine/worker.cjs');

const temp=fs.realpathSync(os.tmpdir());
const root=fs.mkdtempSync(path.join(temp,'oval-nationale-22-'));
const now=Date.UTC(2026,9,16);
const open=dir=>createBridge({dataDir:dir,seed:410,now});
const issue=(b,command,payload={})=>b.handle({id:1,command,payload});
function good(b,command,payload){
 const result=issue(b,command,payload);
 assert.equal(result.ok,true,result.error);
 return result.model;
}
function savePath(dir){return path.join(dir,'PrototypeGodot','donnees.json');}
function create(mode,club){
 const dir=path.join(root,mode),b=open(dir);
 try{assert.equal(settleClubMeetings(good(b,'new_career',{mode,club}),(command,payload)=>good(b,command,payload)).selection.valid,true);}
 finally{b.close();}
 return JSON.parse(fs.readFileSync(savePath(dir),'utf8'));
}
function fixture(template,name,configure){
 const profile=structuredClone(template),state=JSON.parse(profile.store['bdt-v1']);
 state.trained=true;
 configure(state,state.clubs[state.club].players);
 profile.store['bdt-v1']=JSON.stringify(state);
 const dir=path.join(root,name);
 fs.mkdirSync(path.dirname(savePath(dir)),{recursive:true});
 fs.writeFileSync(savePath(dir),JSON.stringify(profile));
 return dir;
}
function leaveVacant(state,players,index){
 const starter=state.lineup[index===1?0:2];
 const position=index===1?'Pilier gauche':'Pilier droit';
 for(const p of players){
  if(p.id!==starter&&(p.pos===position||p.nationaleQualifications?.includes(position)))p.injury=3;
 }
 state.reserves[index]=null;
}
function rejectWithoutWrite(b,dir,payload){
 const before=fs.readFileSync(savePath(dir));
 assert.equal(issue(b,'begin_match',payload).ok,false);
 assert.deepEqual(fs.readFileSync(savePath(dir)),before);
 assert.equal(good(b,'snapshot').live,null);
}

try{
 const template=create('world-nationale',90);
 const normal=path.join(root,'world-nationale');
 let b=open(normal);
 try{
  assert.equal(good(b,'snapshot').selection.reducedBench,undefined);
  rejectWithoutWrite(b,normal,{reducedBench:true});
  rejectWithoutWrite(b,normal,{reducedBench:22});
  const started=good(b,'begin_match');
  assert.equal(started.live.nominationSize,undefined);
  assert.equal(started.live.reserves.length,8);
 }finally{b.close();}

 for(const index of [1,2]){
  const dir=fixture(template,'prop-'+index,(s,p)=>leaveVacant(s,p,index));
  b=open(dir);
  try{
   const waiting=good(b,'snapshot');
   assert.equal(waiting.selection.valid,false);
   assert.deepEqual(waiting.selection.reducedBench,{size:22,vacantNumber:16+index});
   rejectWithoutWrite(b,dir,{});
   const kickoff=good(b,'begin_match',{reducedBench:true});
   assert.equal(kickoff.selection.reducedBench,undefined);
   assert.equal(kickoff.live.nominationSize,22);
   assert.equal(kickoff.live.reserves.length,7);
   const talk=kickoff.clubLife.matchTalks.scene;
   assert.equal(talk.phase,'pre');
   assert.equal(talk.participants.length,22);
   assert.deepEqual(talk.participants.map(p=>p.number),Array.from({length:23},(_,i)=>i+1).filter(n=>n!==16+index));
   assert.deepEqual(talk.participants.map(p=>p.id),[...waiting.lineup,...waiting.reserves].filter(Boolean));
   const exported=good(b,'export').meta.exportText;
   const {state}=JSON.parse(exported);
   assert.deepEqual(state.live.sheets.map(sh=>sh.nominated.length).sort(),[22,23]);
   assert.deepEqual(state.live.uncontestedScrums,[0,0]);
   assert.equal(state.reserves.length,8);
   b.close();b=open(dir);
   assert.equal(good(b,'snapshot').live.paused,true);
   assert.equal(good(b,'import',{text:exported}).live.nominationSize,22);
   if(index===1){
    assert.equal(good(b,'delegate').live.finished,true);
    const next=good(b,'finish_round');
    assert.equal(next.live,null);
    assert.equal(next.meta.week,waiting.meta.week+1);
   }
  }finally{b.close();}
 }

 for(const [name,configure] of [
  ['available',s=>{s.reserves[1]=null;}],
  ['hooker',s=>{s.reserves[0]=null;}],
  ['two-props',(s,p)=>{leaveVacant(s,p,1);leaveVacant(s,p,2);}],
  ['missing-starter',(s,p)=>{leaveVacant(s,p,1);s.lineup[0]=null;}],
 ]){
  const dir=fixture(template,name,configure);b=open(dir);
  try{
   assert.equal(good(b,'snapshot').selection.reducedBench,undefined,name);
   rejectWithoutWrite(b,dir,{reducedBench:true});
  }finally{b.close();}
 }
 const other=fixture(create('fiction',0),'other',(s,p)=>leaveVacant(s,p,1));
 b=open(other);
 try{
  assert.equal(good(b,'snapshot').selection.reducedBench,undefined);
  rejectWithoutWrite(b,other,{reducedBench:true});
 }finally{b.close();}
 console.log('PASS Nationale : les deux piliers, refus atomiques, 22 contre 23, import et reprise, validation de journée');
}finally{
 assert.equal(path.dirname(fs.realpathSync(root)),temp);
 fs.rmSync(root,{recursive:true,force:true});
}
