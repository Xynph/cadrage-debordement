'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const a=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{createBridge}=require('../native/engine/worker.cjs'),C=require('../native/engine/staff-completion.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'staff-completion-season-'));let bridge=createBridge({dataDir:root,seed:413,now:1700000000000}),seq=0,model;
function good(command,payload={}){const r=bridge.handle({id:++seq,command,payload});a.equal(r.ok,true,command+': '+r.error);return model=r.model;}
function signed(doc){let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 good('new_career',{mode:'fiction',club:13});model=settleClubMeetings(model,good);const doc=JSON.parse(good('export').meta.exportText);
 // A validator-compatible ended historical career exercises the actual worker
 // season command; no claim that this fixture played a full sporting season.
 Object.assign(doc.state,{phase:'ended',round:26,live:null,ending:'Bilan de fin de saison du scénario de test',playoff:{pairs:[],seeds:[0,1,2,3,4,5],log:[]}});
 doc.state.clubs[0].base=81;doc.state.clubs[1].base=71;
 const targets=JSON.stringify(doc.state.staffCareer.targets),origins=JSON.stringify(doc.state.staffCareer.completionOrigins),faces=new Map(doc.state.staffCareer.people.flat().filter(p=>p.clubId!==null).map(p=>[p.id,{name:p.name,level:p.level,appearanceId:p.appearanceId,appearanceAge:p.appearanceAge,generation:p.generation}]));
 good('import',{text:signed(doc)});good('next_season',{confirmed:true});a.equal(model.meta.season,2);const after=JSON.parse(good('export').meta.exportText).state;
 a.ok(after.clubs[0].base>=82,'The real annual AI update crosses81→82');a.ok(after.clubs[1].base>=72,'The real annual AI update crosses71→72');a.equal(JSON.stringify(after.staffCareer.targets),targets);a.equal(JSON.stringify(after.staffCareer.completionOrigins),origins);
 for(const p of after.staffCareer.people.flat()){const old=faces.get(p.id);if(old)a.deepEqual({name:p.name,level:p.level,appearanceId:p.appearanceId,appearanceAge:p.appearanceAge,generation:p.generation},old,'Retained staff keep their identity/level/portrait when sporting power changes');}
 for(const t of model.staff.teams.filter(t=>t.id!==13))for(const [key,n] of Object.entries(C.MINIMUM))a.ok(C.coverage(t.members)[key]>=n,key+' AIclub'+t.id);
 const saved=good('export').meta.exportText;good('shutdown');bridge=createBridge({dataDir:root,now:1700000000000});good('snapshot');a.ok(good('export').meta.exportText===saved,'Real season transition reopens without regeneration');
 console.log('Native staff completion season: real next_season, annual AI71→72/81→82 crossings, immutable creation targets/origins/faces and restart PASS.');
}finally{bridge.close();fs.rmSync(root,{recursive:true,force:true});}
