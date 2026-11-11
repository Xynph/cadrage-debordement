'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const profiling=process.env.CD_YOUTH_SCOUT_PROFILE==='1';
const suiteStarted=profiling?process.hrtime.bigint():null,suiteCPU=profiling?process.cpuUsage():null;
if(profiling)process.once('exit',()=>console.log('YOUTH_SCOUT_PROFILE '+JSON.stringify({scope:'suite',wallMs:Number(process.hrtime.bigint()-suiteStarted)/1e6,cpu:process.cpuUsage(suiteCPU)})));
const {createBridge}=require('../native/engine/worker.cjs');
function fixture(t,mode='world',club=0){
 const started=profiling?process.hrtime.bigint():null,cpu=profiling?process.cpuUsage():null,metrics=new Map();
 function measure(operation,run){
  if(!profiling)return run();
  const start=process.hrtime.bigint(),before=process.cpuUsage();let result,thrown=false;
  try{result=run();return result;}catch(error){thrown=true;throw error;}finally{
   const wallMs=Number(process.hrtime.bigint()-start)/1e6,used=process.cpuUsage(before);
   const row=metrics.get(operation)||{operation,count:0,wallMs:0,userMs:0,systemMs:0,maxMs:0,refused:0,thrown:0};
   row.count++;row.wallMs+=wallMs;row.userMs+=used.user/1000;row.systemMs+=used.system/1000;row.maxMs=Math.max(row.maxMs,wallMs);row.refused+=Number(result?.ok===false);row.thrown+=Number(thrown);metrics.set(operation,row);
  }
 }
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-youth-scout-native-'));
 let bridge=measure('createBridge',()=>createBridge({dataDir:root,seed:827381,now:1794178800000})),id=0;
 t.after(()=>{
  try{measure('cleanup',()=>{bridge.close();fs.rmSync(root,{recursive:true,force:true});});}finally{
   if(profiling)console.log('YOUTH_SCOUT_PROFILE '+JSON.stringify({scope:'scenario',name:t.name,mode,club,wallMs:Number(process.hrtime.bigint()-started)/1e6,cpu:process.cpuUsage(cpu),operations:[...metrics.values()]}));
  }
 });
 const send=(command,payload={})=>measure('command:'+command,()=>bridge.handle({id:++id,command,payload}));
 const go=(command,payload)=>{const r=send(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};
 settleClubMeetings(go('new_career',{mode,club}),(command,payload)=>go(command,payload));
 return {send,go,root,file:path.join(root,'PrototypeGodot/donnees.json'),export:()=>go('export').meta.exportText,state:()=>JSON.parse(go('export').meta.exportText).state,legacyAnnual:()=>measure('legacyAnnualFixture',legacyAnnualFixture),restart:()=>measure('restart',()=>{bridge.close();bridge=createBridge({dataDir:root,seed:1,now:1});})};
}
const bytes=f=>fs.readFileSync(f.file),profile=f=>JSON.parse(bytes(f));
test('Registered regen domain exposes real adult supply while repeated projection preserves the entire career and profile',t=>{
 const f=fixture(t),m=f.go('snapshot'),data=m.clubLife.regenScouting;a.ok(data,'regen domain must be in the production manifest');a.equal(data.missionCommand,'scout_mission');a.equal(data.recruitCommand,'recruit');a.ok(data.candidates.length>0);a.ok(data.candidates.every(p=>p.age>=18));
 const before=f.export(),disk=bytes(f);for(let i=0;i<3;i++)f.go('snapshot');a.equal(f.export(),before);a.deepEqual(bytes(f),disk);
 const p=data.candidates[0],prior=f.state(),privateBefore=profile(f);const after=f.go('regen_shortlist',{playerId:p.id,watched:true,context:data.context});a.ok(after.clubLife.regenScouting.shortlist.some(q=>q.id===p.id));const state=f.state();a.deepEqual(state.clubs,prior.clubs);a.equal(profile(f).seed,privateBefore.seed);a.equal(profile(f).clock,privateBefore.clock);a.deepEqual(state.manager.watch,[...prior.manager.watch,p.id]);
 const exact=f.export(),saved=bytes(f);f.restart();a.equal(f.export(),exact);a.deepEqual(bytes(f),saved);
});

test('Youth observations require explicit opt-in and activation preserves game data, cash, clock and RNG',t=>{
 const f=fixture(t,'common');let m=f.go('snapshot'),data=m.clubLife.youthDevelopment;a.ok(data,'youth domain must be registered');a.equal(data.enabled,false);a.equal(f.state().youthDevelopment,undefined);
 const before=f.export(),disk=bytes(f);f.go('snapshot');a.equal(f.export(),before);a.deepEqual(bytes(f),disk);f.restart();a.equal(f.export(),before);a.equal(f.state().youthDevelopment,undefined,'reopening must not activate measurements');m=f.go('import',{text:before});a.equal(f.export(),before,'import must not create measurements');
 const game=f.state(),privateBefore=profile(f);m=f.go('youth_development_enable',{context:m.clubLife.youthDevelopment.context,confirmed:true});a.equal(m.clubLife.youthDevelopment.enabled,true);const enabled=f.state();a.ok(enabled.youthDevelopment);delete enabled.youthDevelopment;a.deepEqual(enabled,game,'activation captures metrics without changing the simulation');a.equal(profile(f).seed,privateBefore.seed);a.equal(profile(f).clock,privateBefore.clock);
 const exact=f.export(),saved=bytes(f);for(let i=0;i<3;i++)f.go('snapshot');a.equal(f.export(),exact);a.deepEqual(bytes(f),saved);f.restart();a.equal(f.export(),exact);a.deepEqual(bytes(f),saved);
});

const confirmed=data=>({context:data.context,confirmed:true});
function youth(f){return f.go('snapshot').clubLife.youthDevelopment;}
function activated(f){return f.go('youth_development_enable',confirmed(youth(f))).clubLife.youthDevelopment;}
function documentWith(text,change){const doc=JSON.parse(text);change(doc.state);const value=JSON.stringify(doc.state);let hash=2166136261;for(let i=0;i<value.length;i++)hash=Math.imul(hash^value.charCodeAt(i),16777619);doc.checksum=(hash>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
function legacyAnnualFixture(){
 const h=require('./france-harness.cjs').context(),r=h.run;
 // Use the established annual-model fixture with unchanged sourced players.
 // Only this factory closure lacks the subsequently introduced weekly engine.
 r(`var CDCommonCareer=(${require('../native/engine/common-rosters.cjs').toString()})();CDCommonCareer.start(0);
 var CDYouthDevelopment=(()=>{const nativeInSeasonDevelopment=undefined;return (${require('../native/engine/youth-development.cjs').factory.toString()})();})();
 var legacyLearner=club().players.find(p=>p.lnrRatingsVersion===1&&p.age<=23&&developmentFocusOptions(p).length);
 if(!legacyLearner)throw Error('Actual annual learner missing');
 CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,legacyLearner.id,'integration',null);CDYouthDevelopment.validate(S);validateCareer(S);`);
 a.equal(r('CDYouthDevelopment.project(S).players.find(p=>p.id===legacyLearner.id).model'),'annual-v11');
 return {text:r('JSON.stringify(createSaveDocument())'),playerId:r('legacyLearner.id'),baseline:r('JSON.stringify(S.youthDevelopment.rows.find(row=>row.id===legacyLearner.id).baseline)')};
}
function unchangedRefusal(f,command,payload){const before=f.export(),disk=bytes(f),reply=f.send(command,payload);a.equal(reply.ok,false,command+' must refuse');a.equal(f.export(),before);a.deepEqual(bytes(f),disk);return reply;}
test('An integration plan uses the same live domain for the real XP split and records actual training once',t=>{
 const f=fixture(t,'common'),data=activated(f),p=data.players.find(p=>p.stage==='academy'&&p.model==='xp'&&p.defaultFocus);a.ok(p);
 const game=f.state(),privateBefore=profile(f);let m=f.go('youth_development_plan',{...confirmed(data),playerId:p.id,plan:'integration',focus:p.defaultFocus});a.equal(m.meta.youthDevelopmentAction.growthAwarded,0);const before=f.state(),source=game.development.academy.find(q=>q.id===p.id),planned=before.development.academy.find(q=>q.id===p.id);a.equal(planned.rating,source.rating);a.equal(planned.dev.xp,source.dev.xp);a.equal(planned.dev.careerMinutes,source.dev.careerMinutes);a.deepEqual(planned.skills,source.skills);a.equal(before.clubs[0].cash,game.clubs[0].cash);a.equal(profile(f).seed,privateBefore.seed);a.equal(profile(f).clock,privateBefore.clock);
 m=settleClubMeetings(f.go('train',{mode:'normal'}),(command,payload)=>f.go(command,payload));const row=m.clubLife.youthDevelopment.players.find(q=>q.id===p.id);a.ok(row.deltas.generalXP>0);a.ok(row.deltas.focusedXP>0);a.ok(Math.abs(row.deltas.generalXP-3*row.deltas.focusedXP)<1e-9,'real integration is 75/25, not the fallback 50/50');a.ok(row.observations.some(o=>o.reason==='trainWeek'));
 const exact=f.export();settleClubMeetings(f.go('train',{mode:'normal'}),(command,payload)=>f.go(command,payload));a.equal(f.export(),exact,'already applied training creates neither growth nor duplicate observation');f.restart();a.equal(f.export(),exact);
});
test('Stale, foreign, unconfirmed and invalid youth decisions preserve public and private state',t=>{
 const f=fixture(t),data=activated(f),p=data.players.find(p=>p.stage==='academy'&&p.defaultFocus);a.ok(p);const payload={...confirmed(data),playerId:p.id,plan:'integration',focus:p.defaultFocus};
 for(const bad of [{...payload,confirmed:false},{...payload,context:{...data.context,week:99}},{...payload,playerId:f.state().clubs[1].players[0].id},{...payload,focus:'money'},{...payload,hidden:1}])unchangedRefusal(f,'youth_development_plan',bad);
 const roster=f.state().clubs[data.context.club].players;
 const professional=data.players.find(p=>p.stage==='professional'&&roster.some(source=>source.id===p.id&&(source.lnrRatingsVersion===1||source.worldRatingsVersion===1)));
 a.ok(professional,'A source-rated young professional must exercise the native growth model');
 a.equal(professional.model,'xp','The native worker installs in-season progression for source-rated professionals');
 unchangedRefusal(f,'youth_development_plan',{...confirmed(data),playerId:professional.id,plan:'unknown-plan',focus:null});
 const legacy=f.legacyAnnual(),imported=f.go('import',{text:legacy.text}),annual=imported.clubLife.youthDevelopment.players.find(p=>p.id===legacy.playerId);a.ok(annual);
 const row=f.state().youthDevelopment.rows.find(row=>row.id===legacy.playerId);a.equal(JSON.stringify(row.baseline),legacy.baseline,'import preserves the actual annual reference');a.equal(row.latest.model,'annual-v11','loading does not rewrite historical observations');a.equal(annual.model,'xp','current sourced players use the weekly engine after a legacy import');a.ok(annual.availablePlans.includes('specialist'));
 const accepted=f.export(),invalid=documentWith(accepted,s=>{const row=s.youthDevelopment.rows.find(row=>row.id===legacy.playerId);row.plan='specialist';row.focus=null;});
 const refusal=unchangedRefusal(f,'import',{text:invalid});a.match(refusal.error,/ciblage incompatible/,'an annual historical plan cannot claim a specialist without a targeted quality');
 const migrated=f.go('youth_development_plan',{...confirmed(imported.clubLife.youthDevelopment),playerId:legacy.playerId,plan:'specialist',focus:annual.defaultFocus});a.equal(migrated.clubLife.youthDevelopment.players.find(p=>p.id===legacy.playerId).plan,'specialist');
 const updated=f.state().youthDevelopment.rows.find(row=>row.id===legacy.playerId);a.equal(JSON.stringify(updated.baseline),legacy.baseline,'a real weekly plan preserves the annual baseline');a.equal(updated.latest.model,'xp','the actual new decision records the weekly model');
});
test('A refused disk publication rolls back a youth plan and the exact request can be retried',t=>{
 const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs'),f=fixture(t),data=activated(f),p=data.players.find(p=>p.stage==='academy'&&p.defaultFocus),payload={...confirmed(data),playerId:p.id,plan:'integration',focus:p.defaultFocus},before=f.export(),disk=bytes(f);
 const reply=refuseSavePublication(f.file,()=>f.send('youth_development_plan',payload));a.equal(reply.ok,false);a.match(reply.error,/sauvegarde/);a.equal(f.export(),before);a.deepEqual(bytes(f),disk);const m=f.go('youth_development_plan',payload);a.equal(m.clubLife.youthDevelopment.players.find(q=>q.id===p.id).plan,'integration');
});
test('Forged youth clocks, impossible metrics and duplicate tracked IDs are rejected atomically',t=>{
 const f=fixture(t);activated(f);const before=f.export();for(const mutate of [s=>s.youthDevelopment.rows[0].latest.season=s.season+1,s=>s.youthDevelopment.rows[0].latest.rating=999,s=>s.youthDevelopment.rows.push(JSON.parse(JSON.stringify(s.youthDevelopment.rows[0])))])unchangedRefusal(f,'import',{text:documentWith(before,mutate)});
});

test('A real recruit arriving after opt-in keeps the first training variation against its pre-session baseline',t=>{
 const f=fixture(t);activated(f);let m=f.go('snapshot');const candidate=m.clubLife.regenScouting.candidates.find(p=>p.available&&p.age<=24);a.ok(candidate);
 m=f.go('recruit',{playerId:candidate.id,salary:100000,years:1,confirmed:true});a.equal(m.meta.negotiation.status,'signed');const before=m.clubLife.youthDevelopment.players.find(p=>p.id===candidate.id);a.ok(before);a.equal(before.tracked,false);a.equal(before.baseline,null,'joining does not invent prior observations');
 m=settleClubMeetings(f.go('train',{mode:'normal'}),(command,payload)=>f.go(command,payload));const after=m.clubLife.youthDevelopment.players.find(p=>p.id===candidate.id);a.equal(after.baseline.generalXP,before.current.generalXP,'baseline is captured before the first real session');a.ok(after.deltas.generalXP>0,'first earned XP must remain observable');a.ok(after.observations.some(o=>o.reason==='trainWeek'));
 const exact=f.export(),disk=bytes(f);f.restart();a.equal(f.export(),exact);a.deepEqual(bytes(f),disk);
});
