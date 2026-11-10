'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const target=path.join(__dirname,'../native/engine/club-meetings.cjs');
assert.ok(fs.existsSync(target),'Mandatory club meetings must have a persisted native domain');
const definition=require(target),plain=x=>JSON.parse(JSON.stringify(x));
function setup(){
 const box={S:{season:1,round:0,phase:'league',club:0,trained:false,economy:{week:0},clubs:[{id:0,cash:200000,players:[{id:'p1',injury:0},{id:'p2',injury:0}]},{id:1,players:[]}],morale:60,trust:60},pressAvailable:true};
 vm.createContext(box);
 vm.runInContext(`const nativeSystems={domain(id){return {project(){const context={season:S.season,week:S.round,club:S.club};if(id==='press')return {context,conference:{available:pressAvailable},lastOutcome:S.pressConference?.lastOutcome};if(id==='clubSupport')return {context,medical:{available:!S.live&&!S.trained&&S.phase==='league',protocols:[{key:'standard'}],players:S.clubs[S.club].players.filter(p=>p.injury>0||p.medicalV68?.stage==='reprise').map(p=>({id:p.id,injury:p.injury,stage:p.medicalV68?.stage||'blesse'}))}};if(id==='clubStrategy')return {context,available:!S.live&&S.phase!=='ended',finance:{cash:S.clubs[S.club].cash,baseForecast:S.clubs[S.club].cash},board:{priority:S.v105to110?.priority||'stabilite',objectives:S.nativeBoardCalendar?.objectives||[]}};return null;}};}};const domain=(${definition.factory.toString()})();`,box);
 return {box,d:vm.runInContext('domain',box),get s(){return box.S;},restore(s){box.S=plain(s);}};
}
const a=setup(),d=a.d;
const pristine=JSON.stringify(a.s);d.project();for(const cmd of ['snapshot','save','export','load','import','shutdown'])d.observe(cmd);assert.equal(JSON.stringify(a.s),pristine,'Read/import paths never create meetings');
d.observe('new_career');let scene=d.project().scene;assert.equal(scene.kind,'press');assert.equal(scene.completed,false);assert.equal(scene.ackAllowed,false);assert.equal(d.project().queue[0].kind,'board');
for(const cmd of ['begin_match','train','tick','pause','delegate','finish_round','next_season','auto_lineup','set_tactics','scene_invitation_open'])assert.throws(()=>d.guard(cmd,{}),/réunion|rendez-vous|point|terminez/i,cmd+' is blocked');
const beforeReads=JSON.stringify(a.s);for(let i=0;i<4;i++)d.project();assert.equal(JSON.stringify(a.s),beforeReads,'Projection has no effect');
assert.throws(()=>d.execute('club_meeting_ack',{meetingId:scene.id}));assert.throws(()=>d.execute('club_meeting_continue',{meetingId:scene.id}));assert.throws(()=>d.guard('press_conference',{context:{season:1,week:1,club:0}}));
assert.equal(d.guard('press_conference',{context:scene.context}),true);a.box.pressAvailable=false;a.s.pressConference={lastOutcome:{context:plain(scene.context)}};d.observe('press_conference',{context:plain(scene.context)});assert.equal(d.project().scene.completed,true);
const saved=plain(a.s);a.restore(saved);assert.equal(d.project().scene.completed,true,'Completed scene survives restart until explicit continue');assert.throws(()=>d.guard('train'));assert.throws(()=>d.guard('press_conference',{context:scene.context}));
d.execute('club_meeting_continue',{meetingId:scene.id});assert.equal(d.project().scene.kind,'board');assert.equal(d.project().receipts.length,1);assert.throws(()=>d.execute('club_meeting_continue',{meetingId:scene.id}),'A closed meeting cannot replay');
scene=d.project().scene;assert.equal(scene.ackAllowed,true);const stats=JSON.stringify({morale:a.s.morale,trust:a.s.trust,cash:a.s.clubs[0].cash});d.execute('club_meeting_ack',{meetingId:scene.id});assert.equal(d.project().scene.completed,true);d.execute('club_meeting_continue',{meetingId:scene.id});assert.equal(d.project().scene,null);assert.equal(JSON.stringify({morale:a.s.morale,trust:a.s.trust,cash:a.s.clubs[0].cash}),stats,'Reading a board report never invents an effect');
const settled=JSON.stringify(a.s);d.observe('auto_lineup');assert.equal(d.project().scene,null);assert.equal(d.project().receipts.length,2);d.validate(a.s);
// Real medical episodes, not countdown changes, create new obligations.
a.s.clubs[0].players[0].injury=3;d.observe('auto_lineup');scene=d.project().scene;assert.equal(scene.kind,'medical');assert.equal(scene.playerId,'p1');assert.equal(scene.ackAllowed,false);assert.throws(()=>d.execute('club_meeting_ack',{meetingId:scene.id}));assert.throws(()=>d.guard('medical_protocol',{context:scene.context,id:'p2',protocol:'standard'}));assert.throws(()=>d.guard('set_player_load',{playerId:'p1',mode:'repos'}));
d.guard('medical_protocol',{context:scene.context,id:'p1',protocol:'standard'});a.s.clubs[0].players[0].medicalV68={version:1,protocol:'standard',stage:'blesse'};d.observe('medical_protocol',{context:scene.context,id:'p1',protocol:'standard'});assert.equal(d.project().scene.completed,true);d.execute('club_meeting_continue',{meetingId:scene.id});
a.s.clubs[0].players[0].injury=2;d.observe('auto_lineup');assert.equal(d.project().scene,null,'A shorter ongoing injury never reopens a completed point');
a.s.clubs[0].players[0].injury=0;a.s.clubs[0].players[0].medicalV68.stage='reprise';a.s.trained=true;d.observe('train');scene=d.project().scene;assert.equal(scene.kind,'medical');assert.equal(scene.ackAllowed,true,'After an already applied session the real medical projection is read only');d.execute('club_meeting_ack',{meetingId:scene.id});d.execute('club_meeting_continue',{meetingId:scene.id});d.observe('auto_lineup');assert.equal(d.project().scene,null,'A read-only reprise is acknowledged once');
// Available reprise keeps the actual plan only after explicit acknowledgement.
const reprise=setup();reprise.s.clubs[0].players[0].medicalV68={version:1,protocol:'standard',stage:'reprise'};reprise.d.observe('auto_lineup');const repriseScene=reprise.d.project().scene;assert.equal(repriseScene.kind,'medical');assert.equal(repriseScene.ackAllowed,true);assert.equal(reprise.d.guard('set_player_load',{playerId:'p1',mode:'repos'}),true);reprise.d.observe('set_player_load',{playerId:'p1',mode:'repos'});assert.equal(reprise.d.project().scene.completed,false,'Adjusting a real reprise load still requires explicit plan confirmation');assert.throws(()=>reprise.d.guard('set_player_load',{playerId:'p2',mode:'repos'}));reprise.d.execute('club_meeting_ack',{meetingId:repriseScene.id});assert.equal(reprise.s.clubMeetings.current.decision.value,'maintain');
// Imported obligations must retain real identities, known fields and evidence.
const pendingWithOutcome=setup();pendingWithOutcome.d.observe('new_career');pendingWithOutcome.s.pressConference={lastOutcome:{context:plain(pendingWithOutcome.d.project().scene.context)}};assert.throws(()=>pendingWithOutcome.d.validate(pendingWithOutcome.s),'A pending press conference cannot already be performed');
const valid=plain(a.s);for(const mutate of [s=>s.clubMeetings.extra=true,s=>s.clubMeetings.version=2,s=>s.clubMeetings.current={...s.clubMeetings.receipts[0],completed:false,decision:null},s=>s.clubMeetings.receipts[1].decision.value='invented_priority',s=>s.clubMeetings.receipts[0].decision.command='client_completed',s=>s.clubMeetings.receipts[0].id='invented']){const bad=plain(valid);mutate(bad);assert.throws(()=>d.validate(bad),/rendez-vous/i);}
const invalidPlayer=setup();invalidPlayer.s.clubs[0].players[0].injury=2;invalidPlayer.d.observe('auto_lineup');const invalid=plain(invalidPlayer.s);invalid.clubMeetings.current.playerId='unknown';assert.throws(()=>invalidPlayer.d.validate(invalid));
const healthy=plain(invalidPlayer.s);healthy.clubs[0].players[0].injury=0;assert.throws(()=>invalidPlayer.d.validate(healthy),'A client cannot invent a medical meeting for a healthy player');
const forged=plain(invalidPlayer.s);forged.clubMeetings.current.completed=true;forged.clubMeetings.current.decision={command:'medical_protocol',value:'standard',stage:'blesse',protocol:'standard'};assert.throws(()=>invalidPlayer.d.validate(forged),'Completed medical needs the actual saved protocol');
assert.throws(()=>reprise.d.execute('club_meeting_continue',{meetingId:repriseScene.id,completed:true}),'Unknown client completion fields reject');
// Actual board evidence and four simulated week intervals, never per-click summons.
for(const command of ['club_board_priority','club_board_project','club_board_objective']){
 const board=setup();board.box.pressAvailable=false;board.d.observe('new_career');const e=board.d.project().scene;assert.equal(e.kind,'board');
 const payload={context:e.context,key:'finances',kind:'video',type:'wins'};board.d.observe(command,payload);assert.equal(board.d.project().scene.completed,false,'No optimistic completion without accepted controller state: '+command);
 if(command==='club_board_priority')board.s.v105to110={priority:'finances'};
 if(command==='club_board_project')board.s.v105to110={projects:[{kind:'video'}]};
 if(command==='club_board_objective')board.s.nativeBoardCalendar={objectives:[{id:'goal:1:0:wins',status:'pending'}]};
 board.d.observe(command,payload);assert.equal(board.d.project().scene.completed,true,command+' completes from actual saved evidence');
}
const cadence=setup();cadence.box.pressAvailable=false;cadence.d.observe('new_career');function ackCadence(){const e=cadence.d.project().scene;cadence.d.execute('club_meeting_ack',{meetingId:e.id});cadence.d.execute('club_meeting_continue',{meetingId:e.id});}ackCadence();
for(let week=1;week<=3;week++){cadence.s.round=week;cadence.d.observe('finish_round');assert.equal(cadence.d.project().scene,null);}
cadence.s.round=4;cadence.d.observe('finish_round');assert.equal(cadence.d.project().scene.kind,'board');assert.match(cadence.d.project().scene.reason,/quatre/);ackCadence();for(let i=0;i<3;i++)cadence.d.observe('set_tactics');assert.equal(cadence.d.project().scene,null);
cadence.s.nativeBoardCalendar={objectives:[{id:'goal:1:0:wins',status:'pending'}]};cadence.d.observe('club_board_objective');assert.equal(cadence.d.project().scene,null);cadence.s.nativeBoardCalendar.objectives[0].status='met';cadence.d.observe('finish_round');assert.equal(cadence.d.project().scene.kind,'board');ackCadence();cadence.d.observe('set_tactics');assert.equal(cadence.d.project().scene,null,'A terminal objective is not repeated');
cadence.s.clubs[0].cash=-1;cadence.d.observe('set_tactics');assert.equal(cadence.d.project().scene.kind,'board');ackCadence();cadence.s.clubs[0].cash=-2;cadence.d.observe('set_tactics');assert.equal(cadence.d.project().scene,null,'An ongoing warning is not repeated on each mutation');
const brokenSource=plain(invalidPlayer.s);brokenSource.clubMeetings.current.sourceKey='medical:1:0:p1:invented';assert.throws(()=>invalidPlayer.d.validate(brokenSource),'Unknown medical episode sources reject');
const noCurrent=setup();noCurrent.d.observe('new_career');const orphanQueue=plain(noCurrent.s);orphanQueue.clubMeetings.current=null;assert.throws(()=>noCurrent.d.validate(orphanQueue),'An unpromoted queue without an active invitation would deadlock');
const healthyQueue=setup();healthyQueue.s.clubs[0].players[0].injury=2;healthyQueue.d.observe('new_career');const staleQueue=plain(healthyQueue.s);staleQueue.clubs[0].players[0].injury=0;assert.throws(()=>healthyQueue.d.validate(staleQueue),'Queued medical facts must remain valid, too');
const queued=setup();queued.s.sceneInvitations={activeId:'private'};queued.s.clubs[0].players[0].injury=2;queued.d.observe('auto_lineup');assert.equal(queued.d.project().scene,null,'An already active invitation remains visible first');assert.equal(queued.d.project().queue[0].kind,'medical');assert.equal(queued.d.guard('scene_invitation_close',{id:'private'}),true);assert.throws(()=>queued.d.guard('train'));queued.s.sceneInvitations.activeId=null;queued.d.observe('scene_invitation_close',{id:'private'});assert.equal(queued.d.project().scene.kind,'medical');
// No unrelated click summons press; actual simulated advancement does.
a.s.trained=false;a.box.pressAvailable=true;d.observe('set_tactics');assert.equal(d.project().scene,null);a.s.round=1;a.s.economy.week=1;d.observe('match_talk_continue');assert.equal(d.project().scene.kind,'press','Post-match continuation uses the actual changed week');
console.log('Native club meetings VM: mandatory pure projection, authoritative completion, persisted continue, episode scheduling PASS.');

// Production worker, using its real validation, command controllers and disk transaction.
const {createBridge}=require('../native/engine/worker.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-club-meetings-'));
let bridge,sequence=0,model;
const call=(command,payload={})=>bridge.handle({id:++sequence,command,payload});
function good(command,payload={}){const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;}
function bad(command,payload={}){const r=call(command,payload);assert.equal(r.ok,false,command+' must reject');return r;}
const exported=()=>good('export').meta.exportText;
const room=()=>model.clubLife.clubMeetings.scene;
function signed(doc){let h=2166136261;for(const ch of JSON.stringify(doc.state))h=Math.imul(h^ch.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
function conference(){const p=model.clubLife.press;return {context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))};}
function settle(){let count=0;while(room()){assert.ok(++count<85,'The bounded queue must terminate');const e=room();if(!e.completed){if(e.kind==='press')good('press_conference',conference());else if(e.kind==='medical'&&!e.ackAllowed)good('medical_protocol',{context:e.context,id:e.playerId,protocol:'standard'});else good('club_meeting_ack',{meetingId:e.id});}good('club_meeting_continue',{meetingId:e.id});}}
try{
 bridge=createBridge({dataDir:root,seed:13,now:1700000000000});good('new_career',{mode:'common',club:29});
 assert.equal(room().kind,'press');assert.deepEqual(model.clubLife.clubMeetings.queue.map(e=>e.kind),['board']);
 const file=path.join(model.meta.dataDir,'donnees.json'),pending=exported(),pendingDisk=fs.readFileSync(file);
 for(let i=0;i<3;i++)good('snapshot');good('save');assert.equal(exported(),pending,'Snapshot, export and explicit save preserve obligations exactly');
 good('shutdown');bridge=createBridge({dataDir:root});good('snapshot');assert.equal(exported(),pending,'Pending meeting survives process restart');
 for(const command of ['train','auto_lineup','begin_match','delegate','finish_round','next_season','set_tactics'])bad(command,{});
 bad('scene_invitation_open',{id:model.clubLife.sceneInvitations.invitations[0].id});bad('club_meeting_ack',{meetingId:room().id});bad('club_meeting_continue',{meetingId:room().id});bad('club_meeting_continue',{meetingId:room().id,completed:true});
 const payload=conference();bad('press_conference',{...payload,answers:[]});assert.equal(exported(),pending);
 const before=exported(),diskBefore=fs.readFileSync(file);
 refuseSavePublication(file,()=>bad('press_conference',payload));assert.equal(exported(),before);assert.deepEqual(fs.readFileSync(file),diskBefore,'Failed publication restores conference effects, pending obligation, disk and saved RNG');
 good('press_conference',payload);assert.equal(room().completed,true);const completed=exported();bad('press_conference',payload);bad('train');assert.equal(exported(),completed);
 good('shutdown');bridge=createBridge({dataDir:root});good('snapshot');assert.equal(room().completed,true);assert.equal(exported(),completed,'Completed meeting also survives restart and still requires continue');
 const pressId=room().id,priorContinue=exported(),continueDisk=fs.readFileSync(file);
 refuseSavePublication(file,()=>bad('club_meeting_continue',{meetingId:pressId}));assert.equal(exported(),priorContinue);assert.deepEqual(fs.readFileSync(file),continueDisk);
 good('club_meeting_continue',{meetingId:pressId});assert.equal(room().kind,'board');assert.equal(model.clubLife.clubMeetings.receipts.length,1);bad('club_meeting_continue',{meetingId:pressId});
 const boardId=room().id,cash=model.clubLife.clubStrategy.finance.cash;
 bad('club_board_project',{context:room().context,kind:'video',confirmed:false});assert.equal(room().completed,false);assert.equal(model.clubLife.clubStrategy.finance.cash,cash);
 good('club_meeting_ack',{meetingId:boardId});assert.equal(room().completed,true);assert.equal(model.clubLife.clubStrategy.finance.cash,cash);assert.equal(room().decision.value,model.clubLife.clubStrategy.board.priority);good('club_meeting_continue',{meetingId:boardId});assert.equal(room(),null);
 // Optional legacy namespaces stay absent throughout import, snapshot and saving.
 const legacy=JSON.parse(exported());delete legacy.state.clubMeetings;good('import',{text:signed(legacy)});const imported=exported();good('snapshot');good('save');assert.equal(JSON.parse(exported()).state.clubMeetings,undefined);
 // A real injured roster member is the source of the first legacy medical room.
 const injured=JSON.parse(imported),person=injured.state.clubs[29].players[0];person.injury=2;person.medicalV68={version:1,protocol:'standard',stage:'blesse'};
 good('import',{text:signed(injured)});assert.equal(room(),null);good('auto_lineup');assert.equal(room().kind,'medical');assert.equal(room().playerId,person.id);assert.equal(room().ackAllowed,false);
 const medicalId=room().id,medicalContext=room().context,other=model.squad.find(p=>p.id!==person.id).id;
 bad('medical_protocol',{context:medicalContext,id:other,protocol:'prudent'});bad('medical_protocol',{context:medicalContext,id:person.id,protocol:'HIA'});bad('club_meeting_ack',{meetingId:medicalId});bad('set_player_load',{playerId:person.id,mode:'repos'});
 const medicalBefore=exported(),medicalDisk=fs.readFileSync(file);
 refuseSavePublication(file,()=>bad('medical_protocol',{context:medicalContext,id:person.id,protocol:'prudent'}));assert.equal(exported(),medicalBefore);assert.deepEqual(fs.readFileSync(file),medicalDisk);
 good('medical_protocol',{context:medicalContext,id:person.id,protocol:'prudent'});assert.equal(room().completed,true);good('club_meeting_continue',{meetingId:medicalId});good('auto_lineup');assert.equal(room(),null,'The unchanged injury does not summon another room');
 const countdown=JSON.parse(exported()),patient=countdown.state.clubs[29].players.find(p=>p.id===person.id);patient.injury=1;good('import',{text:signed(countdown)});good('auto_lineup');assert.equal(room(),null,'An ongoing injury countdown is not a new episode');
 const repriseDoc=JSON.parse(exported()),recovering=repriseDoc.state.clubs[29].players.find(p=>p.id===person.id);recovering.injury=0;recovering.medicalV68.stage='reprise';good('import',{text:signed(repriseDoc)});good('auto_lineup');assert.equal(room().kind,'medical');assert.equal(room().ackAllowed,true);
 good('set_player_load',{playerId:person.id,mode:'repos'});assert.equal(room().completed,false,'A reprise load adjustment is real, but does not close the meeting');bad('set_player_load',{playerId:other,mode:'repos'});
 const recoveryBefore=JSON.stringify(JSON.parse(exported()).state.clubs[29].players.find(p=>p.id===person.id)),recoveryId=room().id;
 good('club_meeting_ack',{meetingId:recoveryId});assert.equal(room().decision.value,'maintain');assert.equal(JSON.stringify(JSON.parse(exported()).state.clubs[29].players.find(p=>p.id===person.id)),recoveryBefore,'Acknowledging the existing recovery plan has no invented healing effect');good('club_meeting_continue',{meetingId:recoveryId});
 // Unknown fields and forged completion cannot be imported over the real career.
 const finishedPress=JSON.parse(completed);finishedPress.state.clubMeetings.current.completed=false;finishedPress.state.clubMeetings.current.decision=null;bad('import',{text:signed(finishedPress)});
 const clean=exported();for(const mutate of [s=>s.clubMeetings.version=2,s=>s.clubMeetings.extra=true,s=>s.clubMeetings.receipts[0].decision.command='client_completed',s=>s.clubMeetings.receipts[0].id='forged']){const doc=JSON.parse(clean);mutate(doc.state);bad('import',{text:signed(doc)});assert.equal(exported(),clean);}
 // The real final post-match continue (not just finish_round) advances and schedules press.
 good('auto_lineup');good('begin_match');good('delegate');good('finish_round');assert.equal(room()?.kind,'press');assert.equal(room().context.week,1);settle();
 assert.equal(room(),null);const final=exported();good('shutdown');bridge=createBridge({dataDir:root});good('snapshot');assert.equal(exported(),final);
 // A legacy save can proceed straight into a match without a baseline mutation.
 good('import',{text:signed(legacy)});assert.equal(JSON.parse(exported()).state.clubMeetings,undefined);good('begin_match');good('delegate');
 const postDoc=JSON.parse(exported()),talk=postDoc.state.contextualMatch.current,post=talk.phases.at(-1);assert.equal(post.phase,'post');assert.equal(postDoc.state.live.finished,true);post.closed=false;post.status=null;post.decision=null;postDoc.state.contextualMatch.receipts=postDoc.state.contextualMatch.receipts.filter(r=>r.key!==talk.key||r.phase!=='post');
 good('import',{text:signed(postDoc)});good('match_talk_continue',{key:talk.key,phase:'post',skip:true});assert.equal(room()?.kind,'press','The first real legacy post-match continuation must also schedule press');settle();
 console.log('Native club meetings production worker: mandatory queue, restart pending/completed, authoritative press/medical, strict import, no repeat, real advancement and atomic rollback PASS.');
}finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
