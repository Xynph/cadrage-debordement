'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const checksum=state=>{let h=2166136261;const s=JSON.stringify(state);for(let i=0;i<s.length;i++)h=Math.imul(h^s.charCodeAt(i),16777619);return (h>>>0).toString(16).padStart(8,'0');};
// Conservative schema-valid capacity fixture: source rosters remain at their
// large initial size and every candidate already has the maximum 12 history
// entries accepted by the save validator. This is not a played 12-year claim.
for(const population of ['generated','released-source'])for(const [mode,club,limit] of [['world',0,16*1024*1024],['world-champ',102,24*1024*1024]])test(mode+' '+population+' maximum persistent pool and full history fit the unchanged save budget',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-population-capacity-'));
 const b=createBridge({dataDir:root,seed:827381,now:1794178800000});let serial=0;
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});
 const ok=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 settleClubMeetings(ok('new_career',{mode,club}),(command,payload)=>ok(command,payload));const doc=JSON.parse(ok('export').meta.exportText),s=doc.state;
 const capacity=Math.min(1900,Math.max(180,s.clubs.length*20)),samples=s.economy.freeAgents;
 if(population==='generated'){
 s.economy.freeAgents=Array.from({length:capacity},(_,i)=>{
  const p=JSON.parse(JSON.stringify(samples[i%samples.length])),slot=Number(p.id.split('-')[2]);
  p.id='small-1-'+slot+'-'+(10000+i);
  p.dev.history=Array.from({length:12},()=>({season:1,age:p.age,start:p.rating,end:p.rating,minutes:100000,appearances:10000}));
  return p;
 });
 }else{
 const released=[];
 for(const c of s.clubs){
  if(c.id===s.club)continue;
  while(c.players.length>23&&released.length<capacity){
   const index=c.players.findLastIndex((p,i)=>i>=23&&p.age>=18);if(index<0)break;const p=c.players.splice(index,1)[0];p.contractEnd=null;p.academy=false;p.condition=100;p.injury=0;
   p.price=Math.round(p.salary*2/1000)*1000;
   p.population={version:1,origin:'released',season:1,availableSince:1,clubId:null};
   p.dev.history=Array.from({length:12},()=>({season:1,age:p.age,start:p.rating,end:p.rating,minutes:100000,appearances:10000}));
   released.push(p);
  }
 }
 assert.equal(released.length,capacity);s.economy.freeAgents=released;
 }
 s.market=JSON.parse(JSON.stringify(s.economy.freeAgents));
 s.aiRoster.population.history[0].available=capacity;
 doc.checksum=checksum(s);const text=JSON.stringify(doc),bytes=Buffer.byteLength(text);
 assert.ok(bytes<limit,bytes+' bytes exceed '+limit+' byte save budget');
 ok('import',{text});const imported=JSON.parse(ok('export').meta.exportText).state;
 assert.equal(imported.economy.freeAgents.length,capacity);
 assert.equal(imported.economy.freeAgents.every(p=>p.dev.history.length===12),true);
 console.log(JSON.stringify({mode,population,clubs:s.clubs.length,capacity,historyPerCandidate:12,bytes,limit,margin:limit-bytes}));
});
