'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs'),{refuseSavePublication}=require('./helpers/save-publication-refusal.cjs'),C=require('../native/engine/staff-completion.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'native-staff-completion-'));let bridge,model,seq=0;
const call=(command,payload={})=>bridge.handle({id:++seq,command,payload});
function good(command,payload={}){const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return model=r.model;}
function bad(command,payload={}){const r=call(command,payload);assert.equal(r.ok,false,command+' must reject');return r;}
const exp=()=>good('export').meta.exportText;
function signed(doc){let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 bridge=createBridge({dataDir:root,seed:3111,now:1700000000000});good('new_career',{mode:'common',club:0});model=settleClubMeetings(model,good);
 assert.equal(model.staff.teams.length,30);for(const t of model.staff.teams){assert(t.members.length>=15);for(const [key,n] of Object.entries(C.MINIMUM))assert(C.coverage(t.members)[key]>=n,key+' club'+t.id);}
 const people=model.staff.teams.flatMap(t=>t.members),supplements=people.filter(p=>p.generation?.sourceId);assert(supplements.length>0);for(const p of supplements){assert.equal(p.sourceKind,'generated');assert.equal(p.identityStatus,'fictional');assert.equal(p.portraitStatus,'synthetic');assert.equal(p.appearanceBankVersion,2);assert.equal(p.sourceStaffId,null);}
 const before=exp(),file=path.join(model.meta.dataDir,'donnees.json'),disk=fs.readFileSync(file);for(let n=0;n<3;n++)good('snapshot');assert.ok(exp()===before,'Exact persisted document: before');good('save');assert.ok(exp()===before,'Exact persisted document: before');assert.equal(JSON.parse(fs.readFileSync(file)).seed,JSON.parse(disk).seed,'Queries/save do not consume game RNG');
 const context=model.clubLife.staffCareer.context,person=model.staff.teams[0].members.find(p=>p.generation?.sourceId&&p.role==='medical'),cash=model.finance.cash;
 good('staff_release',{context,staffId:person.id,confirmed:true});const count=model.staff.teams[0].members.length,saved=exp();assert.equal(model.finance.cash,cash);assert(!model.staff.teams[0].members.some(p=>p.id===person.id));
 good('shutdown');bridge=createBridge({dataDir:root,now:1700000000000});good('snapshot');assert.ok(exp()===saved,'Exact persisted document: saved');assert.equal(model.staff.teams[0].members.length,count);assert(!model.staff.teams[0].members.some(p=>p.id===person.id),'Dismissed identity remains dismissed after reload');
 good('import',{text:saved});assert.ok(exp()===saved,'Exact persisted document: saved');assert.equal(model.staff.teams[0].members.length,count);
 const candidate=model.clubLife.staffCareer.candidates.find(p=>p.sourceKind==='generated'),payload={context:model.clubLife.staffCareer.context,candidateId:candidate.id,years:1,confirmed:true},stateBefore=exp(),diskBefore=fs.readFileSync(file);
 refuseSavePublication(file,()=>bad('staff_hire',payload));assert.ok(exp()===stateBefore,'Exact persisted document: stateBefore');assert.deepEqual(fs.readFileSync(file),diskBefore,'Failure restores exact staff generation, roster and disk');
 good('staff_hire',payload);assert(model.staff.teams[0].members.some(p=>p.id===candidate.id));assert.equal(model.finance.cash,cash);const hired=exp();
 for(const mutate of [s=>s.staffCareer.completionPolicy='other',s=>s.staffCareer.completionOrigins[0].base--,s=>s.staffCareer.people.flat().find(p=>p.sourceKind==='reference').roleLabel='Médecin du club',s=>s.staffCareer.targets[0].functions.doctor=0,s=>s.staffCareer.people.flat().find(p=>p.generation).level=99,s=>{const p=s.staffCareer.people.flat().find(p=>p.generation?.sourceId);p.sourceKind='reference';p.sourceStaffId=p.generation.sourceId;}]){const doc=JSON.parse(hired);mutate(doc.state);bad('import',{text:signed(doc)});assert.ok(exp()===hired,'Hostile provenance/targets import rejects atomically');}
 const old=JSON.parse(hired);delete old.state.staffCareer;good('import',{text:signed(old)});const legacy=exp();good('snapshot');good('save');assert.ok(exp()===legacy,'Exact persisted document: legacy');assert.equal(JSON.parse(exp()).state.staffCareer,undefined,'Existing inactive save is not automatically activated or staffed');assert(model.staff.teams.every(t=>t.members.filter(p=>!p.historical).length>=15),'Initial reference view still shows the completed base');
 good('new_career',{mode:'world-champ',club:110});model=settleClubMeetings(model,good);assert.equal(model.staff.teams.length,116);for(const t of model.staff.teams){assert(t.members.length>=15);for(const [key,n] of Object.entries(C.MINIMUM))assert(C.coverage(t.members)[key]>=n,key+' world club'+t.id);}
 const worldExport=exp();assert(Buffer.byteLength(worldExport)<24*1024*1024);good('shutdown');bridge=createBridge({dataDir:root,now:1700000000000});good('snapshot');assert.ok(exp()===worldExport,'Exact persisted document: worldExport');assert.equal(model.staff.teams.length,116);
 console.log('Native staff completion: France30/World116 role coverage, fictional provenance/portraits, pure queries, dismissal persistence, strict import, zero costs/RNG and publication rollback PASS.');
}finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
