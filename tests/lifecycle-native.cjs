'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs'),staff=require('../native/engine/staff.cjs');
function fixture(t,mode='common',club=0){const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-lifecycle-native-'));let b=createBridge({dataDir:root,seed:827381,now:1794178800000}),n=0;t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});const send=(command,payload={})=>b.handle({id:++n,command,payload}),go=(command,payload)=>{const r=send(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};settleClubMeetings(go('new_career',{mode,club}),(command,payload)=>go(command,payload));return {send,go,export:()=>go('export').meta.exportText,state:()=>JSON.parse(go('export').meta.exportText).state,file:path.join(root,'PrototypeGodot/donnees.json'),restart:()=>{b.close();b=createBridge({dataDir:root,seed:1,now:1});}};}
const context=m=>({season:m.meta.season,week:m.meta.week,club:m.club.id}),confirmed=m=>({confirmed:true,context:context(m)});
function documentWith(text,change){const doc=JSON.parse(text);change(doc.state);const serialized=JSON.stringify(doc.state);let h=2166136261;for(let i=0;i<serialized.length;i++)h=Math.imul(h^serialized.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
function legacy(text){return documentWith(text,s=>{delete s.staffCareer;s.aiRosterVersion=1;s.aiRoster.version=1;delete s.aiRoster.population;s.market=[];s.economy.freeAgents=[];});}
const bytes=f=>fs.readFileSync(f.file),privateState=f=>JSON.parse(bytes(f));
test('New careers expose population v2 and a dynamic staff without mutating reference sources',t=>{
 const before=crypto.createHash('sha256').update(JSON.stringify(staff.forDatabase('rugby-world-2026-11-09-champ-v5').registry)).digest('hex');
 for(const mode of ['common','world','world-champ','fiction','france']){const f=fixture(t,mode),m=f.go('snapshot');a.equal(m.meta.population.version,2);a.equal(m.meta.population.active,true);a.equal(m.clubLife.staffCareer.active,true);a.equal(m.staff.teams.length,m.meta.mode==='world'?m.meta.database.clubCount:mode==='fiction'?14:30);a.ok(m.staff.teams[0].members.every(p=>p.personState==='career'&&p.id.startsWith('staff-career:')));const saved=bytes(f);f.go('snapshot');a.deepEqual(bytes(f),saved);}
 a.equal(crypto.createHash('sha256').update(JSON.stringify(staff.forDatabase('rugby-world-2026-11-09-champ-v5').registry)).digest('hex'),before);
});
test('Old-save reading stays inactive; either lifecycle can be enabled independently with exact context',t=>{
 const f=fixture(t),old=legacy(f.export());let m=f.go('import',{text:old});a.equal(m.meta.population.version,1);a.equal(m.meta.population.active,false);a.equal(m.clubLife.staffCareer.active,false);a.ok(m.staff.teams[0].members.every(p=>!p.id.startsWith('staff-career:')),'reference directory retained for legacy UI');a.deepEqual(f.state(),JSON.parse(old).state);
 const before=bytes(f),state=f.state();for(const payload of [{confirmed:false,context:context(m)},{confirmed:true,context:{...context(m),week:9}},{...confirmed(m),hidden:1}]){a.equal(f.send('population_enable',payload).ok,false);a.deepEqual(bytes(f),before);a.deepEqual(f.state(),state);}
 let p=privateState(f);m=f.go('staff_career_enable',confirmed(m));a.equal(m.meta.population.active,false);a.equal(m.clubLife.staffCareer.active,true);a.equal(privateState(f).seed,p.seed);a.equal(privateState(f).clock,p.clock);
 p=privateState(f);m=f.go('population_enable',confirmed(m));a.equal(m.meta.population.active,true);a.equal(m.clubLife.staffCareer.active,true);a.equal(privateState(f).seed,p.seed);a.equal(privateState(f).clock,p.clock);a.equal(m.club.cash,state.clubs[state.club].cash);
 const activeWithoutStaff=documentWith(f.export(),s=>delete s.staffCareer);m=f.go('import',{text:activeWithoutStaff});a.equal(m.meta.population.active,true);a.equal(m.clubLife.staffCareer.active,false);m=f.go('staff_career_enable',confirmed(m));a.equal(m.meta.population.active,true);a.equal(m.clubLife.staffCareer.active,true);
 const exact=f.export(),disk=bytes(f);f.restart();a.equal(f.export(),exact);a.deepEqual(bytes(f),disk);
});
test('Staff hires, renewals and release return stable command IDs, cost no cash and consume no RNG',t=>{
 const f=fixture(t);let m=f.go('snapshot');const p=m.clubLife.staffCareer.candidates.find(p=>p.canHire),before=f.state(),privateBefore=privateState(f);
 m=f.go('staff_hire',{...confirmed(m),candidateId:p.id,years:1});a.equal(m.meta.staffCareerAction.staffId,p.id);let person=m.clubLife.staffCareer.teams[0].members.find(q=>q.id===p.id);a.ok(person&&person.canRenew);a.ok(m.staff.teams[0].members.some(q=>q.id===p.id));
 m=f.go('staff_renew',{...confirmed(m),staffId:p.id,years:person.minYears});person=m.clubLife.staffCareer.teams[0].members.find(q=>q.id===p.id);a.ok(person.contractEnd>=2);
 m=f.go('staff_release',{...confirmed(m),staffId:p.id});a.ok(!m.staff.teams[0].members.some(q=>q.id===p.id));a.ok(m.clubLife.staffCareer.candidates.some(q=>q.id===p.id));
 const after=f.state();a.equal(after.clubs[0].cash,before.clubs[0].cash);a.deepEqual(after.clubs[0].players,before.clubs[0].players);a.equal(privateState(f).seed,privateBefore.seed);a.equal(privateState(f).clock,privateBefore.clock);
});
test('Refused stale, foreign and invalid staff commands preserve state and disk',t=>{
 const f=fixture(t),m=f.go('snapshot'),before=f.export(),disk=bytes(f),candidate=m.clubLife.staffCareer.candidates[0],other=m.clubLife.staffCareer.teams[1].members[0];
 const requests=[['staff_hire',{...confirmed(m),candidateId:candidate.id,years:4}],['staff_hire',{...confirmed(m),candidateId:'missing',years:1}],['staff_release',{...confirmed(m),staffId:other.id}],['staff_release',{...confirmed(m),staffId:m.staff.teams[0].members[0].id,context:{...context(m),season:2}}],['staff_career_enable',confirmed(m)]];
 for(const [command,payload]of requests){a.equal(f.send(command,payload).ok,false);a.equal(f.export(),before);a.deepEqual(bytes(f),disk);}
});
test('A real disk refusal rolls back a staff hire and permits the exact retry',t=>{
 const f=fixture(t),m=f.go('snapshot'),candidate=m.clubLife.staffCareer.candidates[0],before=f.export(),disk=bytes(f),backup=path.join(path.dirname(f.file),'donnees-precedentes.json');a.equal(fs.existsSync(backup),false);fs.mkdirSync(backup);
 const payload={...confirmed(m),candidateId:candidate.id,years:1};a.equal(f.send('staff_hire',payload).ok,false);a.equal(f.export(),before);a.deepEqual(bytes(f),disk);fs.rmdirSync(backup);const after=f.go('staff_hire',payload);a.ok(after.staff.teams[0].members.some(p=>p.id===candidate.id));
});
test('Staff import validation rejects forged clocks and qualification references atomically',t=>{
 const f=fixture(t),before=f.export(),disk=bytes(f);
 for(const mutate of [s=>s.staffCareer.lastAdvancedSeason=-1,s=>s.staffCareer.people[0][0].ageSeason=0,s=>s.staffCareer.people[0][0].sourceStaffId='staff:unknown']){const bad=documentWith(before,mutate);a.equal(f.send('import',{text:bad}).ok,false);a.equal(f.export(),before);a.deepEqual(bytes(f),disk);}
});
test('Voluntary retirement uses an eligible real staff member and preserves player data',t=>{
 const f=fixture(t);let m=f.go('snapshot');const team=m.clubLife.staffCareer.teams.find(t=>t.members.some(p=>p.age>=60));a.ok(team);m=settleClubMeetings(f.go('new_career',{mode:'common',club:team.id}),(command,payload)=>f.go(command,payload));const person=m.clubLife.staffCareer.teams[team.id].members.find(p=>p.canRetire);a.ok(person);const before=f.state();m=f.go('staff_retire',{...confirmed(m),staffId:person.id});a.ok(m.clubLife.staffCareer.retired.some(e=>e.id===person.id));a.ok(!m.staff.teams[team.id].members.some(p=>p.id===person.id));a.deepEqual(f.state().clubs[team.id].players,before.clubs[team.id].players);
});
test('Presented identity wins over sanitized reference labels while command IDs remain stable',()=>{
 const person={id:'staff-career:reference:staff:1:source',sourceStaffId:'staff:1:source',name:'Nom et référence',role:'coach',roleLabel:'Entraîneur estimé',identity:{role:'Entraîneur du pack',id:'staff:1:source',name:'Nom officiel & référence',portraitPath:'/tmp/fixture-portrait.png',portraitStatus:'official'}};
 const model={staff:{teams:[{id:1,members:[JSON.parse(JSON.stringify(person))]}]},clubLife:{staffCareer:{active:true,teams:[{id:1,members:[JSON.parse(JSON.stringify(person))]}],candidates:[JSON.parse(JSON.stringify(person))],market:[JSON.parse(JSON.stringify(person))]}}};
 staff.applyCareerPresentation(model);for(const p of [model.staff.teams[0].members[0],model.clubLife.staffCareer.teams[0].members[0],model.clubLife.staffCareer.candidates[0],model.clubLife.staffCareer.market[0]]){a.equal(p.role,'coach');a.equal(p.roleLabel,'Entraîneur du pack');a.equal(p.name,'Nom officiel & référence');a.equal(p.portraitPath,'/tmp/fixture-portrait.png');a.equal(p.portraitStatus,'official');a.equal(p.id,person.id);a.equal(p.sourceStaffId,person.sourceStaffId);}
});
