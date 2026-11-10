'use strict';
const assert=require('node:assert/strict'),test=require('node:test'),vm=require('node:vm');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const definition=require('../native/engine/club-meetings.cjs');
const plain=x=>JSON.parse(JSON.stringify(x));

// The domain runs in its real serialized VM form; only neighbouring projections
// are fixed fixtures. The public-worker case below exercises the actual systems.
function setup(role){
 const box=vm.createContext({S:{season:1,round:0,phase:'league',club:0,trained:false,
  clubs:[{cash:100000,players:[{id:'p1',injury:0}]}],morale:60,trust:60,
  ...(role?{national:{role}}:{})}});
 vm.runInContext(`const nativeSystems={domain(id){return {project(){
  const context={season:S.season,week:S.round,club:S.club};
  if(id==='press')return {context,conference:{available:!S.pressConference?.lastOutcome}};
  if(id==='clubSupport')return {medical:{players:S.clubs[0].players.filter(p=>p.injury>0)}};
  if(id==='clubStrategy')return {context,board:{objectives:[]},finance:{cash:100000,baseForecast:100000}};
 }}}};const domain=(${definition.factory.toString()})();`,box);
 return {box,d:vm.runInContext('domain',box),get s(){return box.S;}};
}
function finishPress(a){
 const e=a.d.project().scene;
 a.s.pressConference={lastOutcome:{context:plain(e.context)}};
 a.d.observe('press_conference',{context:plain(e.context)});
 a.d.execute('club_meeting_continue',{meetingId:e.id});
}

test('national-only creation never schedules club press, medical or board obligations',()=>{
 const a=setup({club:false,nation:'FRA'});a.s.clubs[0].players[0].injury=2;
 const before=JSON.stringify(a.s);a.d.observe('new_career');
 assert.equal(a.d.project().scene,null,'A selector has no mandatory club scene');
 assert.deepEqual(plain(a.d.project().queue),[]);
 assert.equal(JSON.stringify(a.s),before,'No club baseline, effect or episode is created without a club mandate');
 assert.equal(a.d.guard('advance_day'),true);
 a.s.round=4;a.d.observe('advance_day');assert.equal(a.d.project().scene,null);
});

test('legacy and dual club mandates retain mandatory scenes and progression guards',()=>{
 for(const role of [undefined,{club:true,nation:null},{club:true,nation:'FRA'}]){
  const a=setup(role);a.d.observe('new_career');
  assert.equal(a.d.project().scene.kind,'press');
  assert.deepEqual(plain(a.d.project().queue.map(e=>e.kind)),['board']);
  assert.throws(()=>a.d.guard('advance_day'),/rendez-vous/);
  assert.throws(()=>a.d.guard('national_take_job',{role:'dual',nation:'FRA',confirmed:true}),/rendez-vous/);
  assert.equal(a.d.guard('national_take_job',{role:'nation',nation:'FRA',confirmed:true}),true,
   'Leaving club responsibility must reach the authoritative mandate controller');
 }
});

test('resumed national-only saves hide and expire old club work without replaying decisions or losing receipts',()=>{
 for(const completed of [false,true]){
  const a=setup();a.s.clubs[0].players[0].injury=2;a.d.observe('new_career');finishPress(a);
  const meetingId=a.d.project().scene.id;
  if(completed){
   a.s.clubs[0].players[0].medicalV68={stage:'blesse',protocol:'standard'};
   a.d.observe('medical_protocol',{context:plain(a.d.project().scene.context),id:'p1',protocol:'standard'});
  }
  const ledger=plain(a.s.clubMeetings);
  a.s.national={role:{club:false,nation:'FRA'}};
  // Obsolete medical evidence and context are immaterial after leaving the club.
  a.s.round=1;a.s.clubs[0].players[0].injury=0;delete a.s.clubs[0].players[0].medicalV68;
  const resumed=JSON.stringify(a.s);
  for(const command of ['snapshot','save','load','import','export','shutdown']){
   a.d.observe(command);assert.equal(a.d.project().scene,null);
   assert.deepEqual(plain(a.d.project().queue),[]);assert.equal(a.d.guard('advance_day'),true);
  }
  assert.equal(JSON.stringify(a.s),resumed,'Reading a resumed career does not replace, draw or mutate state');
  assert.equal(a.d.validate(a.s),true,'Historical obligations cannot invalidate a national-only resume');
  for(const command of ['club_meeting_ack','club_meeting_continue'])assert.throws(()=>a.d.execute(command,{meetingId}),/club|mandat/i);
  assert.equal(JSON.stringify(a.s),resumed,'A direct domain call cannot acknowledge or replay old work');
  const forged=plain(a.s);forged.clubMeetings.receipts[0].decision.command='invented';
  assert.throws(()=>a.d.validate(forged),'Historical receipts retain their strict validation without a club mandate');
  const effects=JSON.stringify({clubs:a.s.clubs,morale:a.s.morale,trust:a.s.trust,press:a.s.pressConference});
  a.d.observe('advance_day');
  assert.equal(a.s.clubMeetings.current,null);assert.deepEqual(plain(a.s.clubMeetings.queue),[]);
  for(const key of ['receipts','seen','serial','observed'])assert.deepEqual(plain(a.s.clubMeetings[key]),ledger[key],key+' remains intact');
  assert.equal(JSON.stringify({clubs:a.s.clubs,morale:a.s.morale,trust:a.s.trust,press:a.s.pressConference}),effects);
  a.d.validate(a.s);
 }
});

function signed(doc){let h=2166136261;for(const ch of JSON.stringify(doc.state))h=Math.imul(h^ch.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
function sameExport(actual,expected,message){
 if(actual===expected)return;
 const actualDoc=JSON.parse(actual),expectedDoc=JSON.parse(expected);
 const diffs=[];
 function compare(a,b,key){
  if(JSON.stringify(a)===JSON.stringify(b)||diffs.length>=8)return;
  if(a&&b&&typeof a==='object'&&typeof b==='object'){
   for(const child of new Set([...Object.keys(a),...Object.keys(b)]))compare(a[child],b[child],key+'.'+child);
  }else diffs.push(key+': '+String(b).slice(0,80)+' -> '+String(a).slice(0,80));
 }
 compare(actualDoc,expectedDoc,'export');
 assert.fail(message+': '+diffs.join('; '));
}

test('public worker: selector creation, role exit with queued club work, legacy resume and daily advance',()=>{
 const {createBridge}=require('../native/engine/worker.cjs');
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'native-nation-meetings-'));
 const options={dataDir:root,seed:13,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true};
 let bridge,sequence=0,model;
 const call=(command,payload={})=>bridge.handle({id:++sequence,command,payload});
 const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;};
 const exported=()=>good('export').meta.exportText;
 const disk=()=>fs.readFileSync(path.join(model.meta.dataDir,'donnees.json'));
 const room=()=>model.clubLife.clubMeetings;
 const noRooms=()=>{assert.equal(room().scene,null);assert.deepEqual(room().queue,[]);};
 const reopen=()=>{good('shutdown');bridge=createBridge(options);good('snapshot');};
 try{
  bridge=createBridge(options);
  // The base world edition uses the same public nationalRole API as world-champ.
  good('new_career',{mode:'world',nationalRole:'nation',nation:'FRA'});
  assert.equal(model.international.role,'nation');noRooms();
  const initial=exported(),initialDisk=disk();good('snapshot');good('save');sameExport(exported(),initial,'Reads/save do not create obligations or effects');
  assert.deepEqual(disk(),initialDisk,'Reads/save also preserve the persisted RNG and full profile');
  for(const command of ['press_conference','club_meeting_ack','club_meeting_continue'])assert.equal(call(command,{}).ok,false,command+' remains reserved to club managers');
  sameExport(exported(),initial,'Rejected club decisions have no effect');
  good('advance_day',{fromDate:model.meta.calendarToday});noRooms();
  const advanced=exported(),advancedDisk=disk();reopen();noRooms();sameExport(exported(),advanced,'National progression survives the real disk restart');
  good('save');assert.deepEqual(disk(),advancedDisk,'Restart/read/save consumes no RNG and replaces no career values');
  good('advance_day',{fromDate:model.meta.calendarToday});noRooms();

  good('new_career',{mode:'world',club:0});assert.equal(room().scene.kind,'press');
  const press=model.clubLife.press;
  good('press_conference',{context:press.context,invitationId:press.conference.invitationId,answers:press.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
  good('club_meeting_continue',{meetingId:room().scene.id});
  assert.equal(room().scene.kind,'board');assert.equal(room().receipts.length,1);
  const oldWork=plain(JSON.parse(exported()).state.clubMeetings);
  const beforeRejected=exported(),rejected=call('national_take_job',{role:'nation',nation:'XXX',confirmed:true});
  assert.equal(rejected.ok,false);good('snapshot');assert.equal(room().scene.kind,'board','Rejected role changes keep the club obligation');
  sameExport(exported(),beforeRejected,'A rejected role change cannot expire club work');
  good('national_take_job',{role:'nation',nation:'FRA',confirmed:true});
  assert.equal(model.international.role,'nation');noRooms();
  assert.deepEqual(room().receipts,oldWork.receipts,'Taking national office keeps completed club receipts');
  const legacy=JSON.parse(exported());legacy.state.clubMeetings=oldWork;
  good('import',{text:signed(legacy)});noRooms();
  const pending=exported();reopen();noRooms();sameExport(exported(),pending,'Legacy queued work stays inert during import and restart');
  good('advance_day',{fromDate:model.meta.calendarToday});noRooms();
  const state=JSON.parse(exported()).state;
  assert.equal(state.clubMeetings.current,null);assert.deepEqual(state.clubMeetings.queue,[]);
  assert.deepEqual(state.clubMeetings.receipts,oldWork.receipts);assert.deepEqual(state.clubMeetings.seen,oldWork.seen);
 }finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
});
