'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-'));let b=createBridge({dataDir:root,seed:408,now:1700000000000}),n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const bad=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,false,command+' doit être refusé');return r;};
try{
 let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),good);assert.ok(m.clubLife.clubSupport,'Projection staff/médical/agents requise.');
 const file=path.join(root,'PrototypeGodot','donnees.json');let text=good('export').meta.exportText,bytes=fs.readFileSync(file);
 for(let i=0;i<3;i++)good('snapshot');assert.equal(good('export').meta.exportText,text);assert.deepEqual(fs.readFileSync(file),bytes);
 let support=m.clubLife.clubSupport,context=support.context;bad('staff_meeting',{context:{...context,week:1},plan:'cohesion'});
 const morale=support.diagnostic.morale;m=good('staff_meeting',{context,plan:'cohesion'});assert.equal(m.clubLife.clubSupport.diagnostic.morale,Math.min(98,morale+3));bad('staff_meeting',{context,plan:'cohesion'});
 m=good('training_plan',{context,plan:'proteger'});assert.ok(m.clubLife.clubSupport.training.plans[0].players.every(p=>p.plan==='repos'||p.plan==='normal'));
 const briefing=m.clubLife.clubSupport.briefing;assert.ok(briefing.available);m=good('strategic_briefing',{context,plan:'pack',fixture:briefing.fixture});assert.equal(m.clubLife.clubSupport.briefing.selected,'pack');
 const offer=m.clubLife.clubSupport.agents.players.flatMap(p=>p.quotes).find(q=>q.policy==='equilibre'&&q.affordable);assert.ok(offer,'Offre éligible réelle.');assert.equal(offer.totalCommitment,offer.wage*34*offer.years+offer.fee);
 m=good('agent_negotiate',{context,id:offer.id,years:offer.years,policy:offer.policy});const talk=m.clubLife.clubSupport.agents.talks.find(t=>t.id===offer.id);assert.ok(talk&&talk.status==='ready');
 const signature={context,key:talk.key,confirmed:true,wage:talk.acceptedSalary,years:talk.years,fee:talk.fee};bad('agent_confirm',{...signature,confirmed:false});bad('agent_confirm',{...signature,fee:talk.fee+1});m=good('agent_confirm',signature);assert.equal(m.clubLife.clubSupport.agents.history[0].status,'signed');bad('agent_confirm',signature);
 text=good('export').meta.exportText;good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.equal(good('export').meta.exportText,text);good('import',{text});
 for(const change of [s=>s.v69Briefing.version=99,s=>s.v71AgentDesk.history[0].policy='faux',s=>s.v71AgentDesk.history[0].id='\n',s=>s.clubs[29].players[0].medicalV68={version:99,protocol:'standard',stage:'blesse'}]){const doc=JSON.parse(text);change(doc.state);bad('import',{text:JSON.stringify(doc)});assert.equal(good('export').meta.exportText,text);}
 m=settleClubMeetings(good('train'),good);bad('staff_meeting',{context,plan:'exigence'});bad('training_plan',{context,plan:'relever'});
 m=good('begin_match');bad('medical_protocol',{context,id:offer.id,protocol:'standard'});good('delegate');m=settleClubMeetings(good('finish_round'),good);context=m.clubLife.clubSupport.context;
 text=good('export').meta.exportText;bytes=fs.readFileSync(file);
 const refused=refuseSavePublication(file,()=>bad('staff_meeting',{context,plan:'recuperation'}));
 assert.match(refused.error,/sauvegarde impossible/);
 assert.equal(good('export').meta.exportText,text);assert.deepEqual(fs.readFileSync(file),bytes);
 console.log('Support vrai worker : staff/plans/briefing/agents, contexte, doublons, 34 semaines, reprise/import, hostile et rollback PASS. '+root);
}finally{b.close();}
