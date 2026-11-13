'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-medical-'));let b=createBridge({dataDir:root,seed:409,now:1700000000000}),n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;},bad=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,false,command);return r;};
const exported=()=>JSON.parse(good('export').meta.exportText),encode=doc=>{let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);};
try{
 settleClubMeetings(good('new_career',{mode:'common',club:29}),good);const base=exported(),id=base.state.clubs[29].players[25].id;
 for(const protocol of ['prudent','standard','accelere']){
  const doc=structuredClone(base),p=doc.state.clubs[29].players.find(p=>p.id===id);p.injury=2;p.condition=40;p.physicalLoad={version:1,fatigue:50,plan:'repos'};
  let m=good('import',{text:encode(doc)}),context=m.clubLife.clubSupport.context;bad('medical_protocol',{context,id:'inconnu',protocol});bad('medical_protocol',{context,id,protocol:'HIA'});
  m=good('medical_protocol',{context,id,protocol});assert.equal(m.clubLife.clubSupport.medical.players.find(p=>p.id===id).protocol,protocol);m=settleClubMeetings(m,good);
  const before=good('export').meta.exportText;good('snapshot');assert.equal(good('export').meta.exportText,before);
  settleClubMeetings(good('train'),good);const state=exported().state,after=state.clubs[29].players.find(p=>p.id===id);
  assert.equal(after.medicalV68.version,1);assert.equal(after.medicalV68.protocol,protocol);assert.ok(after.injury>=0&&after.injury<=2);
  if(protocol==='prudent'){assert.equal(after.injury,1);assert.equal(after.condition,60);assert.equal(after.physicalLoad.fatigue,20);}
  if(protocol==='standard'){assert.equal(after.injury,1);assert.equal(after.condition,55);assert.equal(after.physicalLoad.fatigue,26);}
  const trained=good('export').meta.exportText;settleClubMeetings(good('train'),good);assert.equal(good('export').meta.exportText,trained,'Deuxième train ne réapplique pas le médical.');
  good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,trained,'Reprise médicale exacte.');
 }
 for(const choice of ['progressif','complet']){
  const doc=structuredClone(base),p=doc.state.clubs[29].players.find(p=>p.id===id);p.injury=0;p.condition=70;p.physicalLoad={version:1,fatigue:40,plan:'normal'};p.medicalV68={version:1,protocol:'standard',stage:'reprise'};
  let m=good('import',{text:encode(doc)}),context=m.clubLife.clubSupport.context;m=good('medical_return',{context,id,choice});const after=exported().state.clubs[29].players.find(p=>p.id===id);
  assert.equal(after.condition,choice==='progressif'?78:63);assert.equal(after.physicalLoad.fatigue,choice==='progressif'?28:52);assert.equal(after.medicalV68.stage,choice==='progressif'?'progressif':'termine');bad('medical_return',{context,id,choice});
 }
 let m=good('import',{text:encode(structuredClone(base))}),context=m.clubLife.clubSupport.context;m=good('staff_meeting',{context,plan:'recuperation'});let doc=exported();doc.state.manager.inbox=[];good('import',{text:encode(doc)});bad('staff_meeting',{context,plan:'cohesion'});
 for(const modify of [s=>s.nativeSupport.version=2,s=>s.nativeSupport.meeting.context.club=30,s=>s.nativeSupport.meeting.plan='faux']){const invalid=structuredClone(doc);modify(invalid.state);assert.match(bad('import',{text:encode(invalid)}).error,/staff/);}
 m=good('import',{text:encode(structuredClone(base))});let count=0;
 for(const p of m.clubLife.clubSupport.agents.players){const q=p.quotes.find(q=>q.policy==='ferme'&&q.affordable);if(!q)continue;for(let attempt=0;attempt<3&&count<27;attempt++){m=good('agent_negotiate',{context,id:q.id,years:q.years,policy:q.policy});count++;}if(count>=27)break;}
 assert.equal(count,27);assert.equal(m.clubLife.clubSupport.agents.history.length,24);doc=exported();good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.deepEqual(good('snapshot').clubLife.clubSupport.agents.history,doc.state.v71AgentDesk.history);
 // This bench deliberately reuses its own temporary profile across many imports.
 // Release one QA checkpoint through the confirmed API; never bypass the player quota.
 const safety=good('snapshot').meta.profileSafety;
 if(safety.entries.length>=safety.maxEntries)good('remove_checkpoint',{id:safety.entries.at(-1).id,confirmed:true});
 settleClubMeetings(good('new_career',{mode:'fiction',club:0}),good);m=good('snapshot');const quote=m.clubLife.clubSupport.agents.players.flatMap(p=>p.quotes)[0];assert.ok(quote);assert.equal(quote.paidWeeks,29);assert.equal(quote.totalCommitment,quote.wage*29*quote.years+quote.fee);
 console.log('Support médical : trois protocoles réels, séance unique, deux retours bornés, reprise, reçu non contournable, historique24 et devis historique29 PASS. '+root);
}finally{b.close();}
