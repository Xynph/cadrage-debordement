'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
// Conservative schema-valid capacity fixture: source rosters remain at their
// large initial size and every candidate already has the maximum 12 history
// entries accepted by the save validator. This is not a played 12-year claim.
for(const population of ['generated','released-source'])for(const [mode,club,limit] of [['world',0,16*1024*1024],['world-champ',102,24*1024*1024]])test(mode+' '+population+' maximum persistent pool and full history fit the unchanged save budget',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-population-capacity-'));
 const options={dataDir:root,seed:827381,now:1794178800000};
 let b=createBridge(options),serial=0;
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});
 const ok=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const model=settleClubMeetings(ok('new_career',{mode,club}),ok),file=path.join(model.meta.dataDir,'donnees.json');
 const profile=JSON.parse(fs.readFileSync(file,'utf8')),s=JSON.parse(profile.store['bdt-v1']);
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
 // Write the synthetic state as a private profile, then exercise the actual
 // portable export. Champ can encode repeated market entries as references.
 b.close();
 profile.store['bdt-v1']=JSON.stringify(s);
 fs.writeFileSync(file,JSON.stringify(profile));
 b=createBridge(options);
 const text=ok('export').meta.exportText,bytes=Buffer.byteLength(text);
 assert.ok(bytes<limit,bytes+' bytes exceed '+limit+' byte save budget');
 const exported=JSON.parse(text);
 if(Buffer.byteLength(profile.store['bdt-v1'])>=limit)assert.equal(exported.exportVersion,2);
 ok('import',{text});
 const imported=JSON.parse(JSON.parse(fs.readFileSync(file,'utf8')).store['bdt-v1']);
 assert.equal(imported.economy.freeAgents.length,capacity);
 assert.equal(imported.economy.freeAgents.every(p=>p.dev.history.length===12),true);
 assert.deepEqual(imported.economy.freeAgents,exported.state.economy.freeAgents);
 assert.deepEqual(imported.market,imported.economy.freeAgents);
 console.log(JSON.stringify({mode,population,clubs:s.clubs.length,capacity,historyPerCandidate:12,bytes,limit,margin:limit-bytes}));
});
