'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const checksum=state=>{let h=2166136261;const s=JSON.stringify(state);for(let i=0;i<s.length;i++)h=Math.imul(h^s.charCodeAt(i),16777619);return (h>>>0).toString(16).padStart(8,'0');};

test('native population state survives import/reopen and rejects corruption or failed persistence atomically',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-player-population-'));
 let b=createBridge({dataDir:root,seed:827381,now:1794178800000}),serial=0;
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});
 const call=(command,payload={})=>b.handle({id:++serial,command,payload});
 const ok=(command,payload)=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const archive=()=>ok('export').meta.exportText;
 const model=settleClubMeetings(ok('new_career',{mode:'world',club:0}),(command,payload)=>ok(command,payload)),before=archive(),doc=JSON.parse(before),s=doc.state;
 assert.equal(s.aiRosterVersion,2);
 assert.equal(s.aiRoster.population.referenceAccessible,s.clubs.reduce((n,c)=>n+c.players.length,0)+s.economy.freeAgents.length);
 assert.equal(s.market.length,s.economy.freeAgents.length);
 assert.ok(Buffer.byteLength(before)<16*1024*1024);
 ok('import',{text:before});assert.equal(archive(),before);
 const bad=JSON.parse(before);bad.state.aiRoster.population.lastPoolSeason=2;bad.checksum=checksum(bad.state);
 assert.equal(call('import',{text:JSON.stringify(bad)}).ok,false);assert.equal(archive(),before);
 const primary=path.join(model.meta.dataDir,'donnees.json'),profile=fs.readFileSync(primary),rename=fs.renameSync;
 fs.renameSync=(from,to)=>{if(path.resolve(to)===primary&&path.basename(from).startsWith('donnees.tmp')){const e=Error('population persistence test');e.code='EACCES';throw e;}return rename(from,to);};
 let rejected;try{rejected=call('train',{mode:'intense'});}finally{fs.renameSync=rename;}
 assert.equal(rejected.ok,false);assert.equal(archive(),before);assert.deepEqual(fs.readFileSync(primary),profile);
 b.close();b=createBridge({dataDir:root,seed:999,now:1794178800000});
 assert.equal(archive(),before,'same player identities, pool, RNG profile and policy after reopening');
 const candidate=JSON.parse(archive()).state.market.find(p=>p.age+2<p.dev.retireAge);
 const cash=JSON.parse(archive()).state.clubs[0].cash;
 const counter=ok('recruit',{confirmed:true,playerId:candidate.id,salary:1000,years:2});
 assert.equal(counter.meta.negotiation.status,'counter');
 const counterExport=archive();ok('import',{text:counterExport});
 const signed=ok('recruit',{confirmed:true,playerId:candidate.id,salary:counter.meta.negotiation.salary,years:2});
 assert.equal(signed.meta.negotiation.status,'signed');
 const after=JSON.parse(archive()).state;
 assert.equal(after.clubs[0].players.some(p=>p.id===candidate.id),true);
 assert.equal(after.economy.freeAgents.some(p=>p.id===candidate.id),false);
 assert.equal(after.clubs[0].cash,cash-counter.meta.negotiation.fee);
 const final=archive();b.close();b=createBridge({dataDir:root,seed:991,now:1794178800000});assert.equal(archive(),final);
});
