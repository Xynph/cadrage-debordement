'use strict';
// A real J1 injury must not leave the next native AI sheet at 22 players.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge,CORE_FILES}=require('../native/engine/worker.cjs'),{context}=require('./france-harness.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_NATIVE_SHEET_TEST_ROOT||os.tmpdir(),'cd-native-sheet-'));
const bridges=[],checks=[],fixtures=new Map();let serial=0;
const clone=x=>JSON.parse(JSON.stringify(x));
function bridge(name,seed){const b=createBridge({dataDir:path.join(root,name),seed,now:1700000000000});bridges.push(b);return b;}
function call(b,command,payload={}){return b.handle({id:++serial,command,payload});}
function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
function state(b){return JSON.parse(good(b,'export').meta.exportText).state;}
function file(name){return path.join(root,name,'PrototypeGodot','donnees.json');}
function profile(name){return JSON.parse(fs.readFileSync(file(name),'utf8'));}
function copied(name,persisted,seed=0){fs.mkdirSync(path.dirname(file(name)),{recursive:true});fs.writeFileSync(file(name),JSON.stringify(persisted));return bridge(name,seed);}
function harness(persisted,options={}){const h=context(persisted.seed,options);h.ctx.fixture=JSON.parse(persisted.store['bdt-v1']);h.run('S=fixture;save=()=>{};validateCareer(S)');return h;}
function allPlayers(s){return [...s.clubs.flatMap(c=>c.players),...s.aiRoster.academies.flatMap(a=>a.players),...s.development.academy,...s.market,...s.economy.freeAgents];}
function qualified(s){for(let side=0;side<2;side++){const sh=s.live.sheets[side],players=s.clubs[s.live.pair[side]].players,ids=[...sh.on,...sh.bench];assert.equal(ids.length,23);assert.equal(new Set(ids).size,23);assert.equal(sh.nominated.length,23);assert.ok(ids.every(id=>typeof id==='string'&&players.some(p=>p.id===id&&!p.injury)));}}
function validateNative(b){const h=context();h.ctx.checked=state(b);h.run('validateCareer(checked)');qualified(state(b));}
function check(label,fn){fn();checks.push(label);}
// Read-only probe of the real worker's VM binding. Production has no test hook.
function inspectedWorker(){
 const Module=require('node:module'),filename=require.resolve('../native/engine/worker.cjs'),m=new Module(filename,module);
 m.filename=filename;m.paths=Module._nodeModulePaths(path.dirname(filename));
 m._compile(fs.readFileSync(filename,'utf8').replace('return {handle,close};',"return {handle,close,matchFactory:()=>run('createRugbyMatch')};"),filename);return m.exports.createBridge;
}
function inspected(name,persisted){fs.mkdirSync(path.dirname(file(name)),{recursive:true});fs.writeFileSync(file(name),JSON.stringify(persisted));const b=inspectedWorker()({dataDir:path.join(root,name),seed:0,now:1700000000000});bridges.push(b);return b;}
function prepare(b,seed){
 good(b,'new_career',{club:0});good(b,'begin_match');
 good(b,'pause',{paused:true});good(b,'pause',{paused:false});good(b,'tick',{steps:1});good(b,'pause',{paused:true});
 good(b,'delegate');good(b,'finish_round');good(b,'auto_lineup');
 if(seed===1)good(b,'promote_cover',{confirmed:true});
 assert.equal(good(b,'snapshot').selection.valid,true);
}
try{
 for(const seed of [1,5])check('native seed '+seed+': healthy J1 profile, J2, export/import/restart and J3 RNG',()=>{
  let b=bridge('seed-'+seed,seed);prepare(b,seed);const before=profile('seed-'+seed);fixtures.set(seed,before);
  const beforeState=state(b),injured='p12-'+(seed===1?23:2)+'-1700000000000';
  assert.equal(beforeState.round,1);assert.equal(beforeState.live,null);assert.equal(beforeState.clubs[12].players.find(p=>p.id===injured).injury,seed===1?3:4);
  const reopened=copied('reopened-'+seed,before);assert.equal(good(reopened,'snapshot').meta.profileError,'');assert.deepEqual(state(reopened),beforeState);
  good(b,'begin_match');good(reopened,'begin_match');validateNative(b);
  assert.deepEqual(state(b),state(reopened),'same saved S and RNG give the same actual J2');
  assert.equal(profile('seed-'+seed).seed,profile('reopened-'+seed).seed);
  const after=state(b),added=after.clubs[12].players.filter(p=>!beforeState.clubs[12].players.some(q=>q.id===p.id));
  assert.equal(added.length,1);assert.equal(added[0].pos,seed===1?'Demi de mêlée':'Pilier droit');assert.equal(after.clubs[12].players.find(p=>p.id===injured).injury,seed===1?2:3);
  good(b,'pause',{paused:true});const text=good(b,'export').meta.exportText,rng=profile('seed-'+seed).seed;
  good(b,'import',{text});assert.equal(good(b,'export').meta.exportText,text);assert.equal(profile('seed-'+seed).seed,rng);
  const saved=state(b),disk=fs.readFileSync(file('seed-'+seed));b.close();b=bridge('seed-'+seed,12345);
  assert.deepEqual(state(b),saved);assert.deepEqual(fs.readFileSync(file('seed-'+seed)),disk,'restart does not rewrite the saved profile');
  const control=copied('continuation-'+seed,profile('seed-'+seed));
  for(const x of [b,control]){const rosters=state(x).clubs.map(c=>c.players.map(p=>p.id));good(x,'delegate');good(x,'finish_round');assert.deepEqual(state(x).clubs.map(c=>c.players.map(p=>p.id)),rosters,'finish_round adds no historical AI cover');good(x,'auto_lineup');if(!good(x,'snapshot').selection.valid)good(x,'promote_cover',{confirmed:true});good(x,'begin_match');validateNative(x);assert.equal(state(x).round,2);}
  assert.deepEqual(state(b),state(control));assert.equal(profile('seed-'+seed).seed,profile('continuation-'+seed).seed,'true J3 continuation retains the RNG');
 });
 check('minimal seed 5 new/begin/delegate/finish/begin needs no UI or human cover',()=>{
  const b=bridge('minimal',5);good(b,'new_career',{club:0});good(b,'begin_match');good(b,'delegate');good(b,'finish_round');good(b,'begin_match');validateNative(b);
 });
 for(const seed of [1,5])check('coverage seed '+seed+': deterministic, idempotent, no healing/cash/history changes',()=>{
  const h=harness(fixtures.get(seed)),before=h.state(),rng=h.seed(),payroll=h.run('aiRosterPayroll(S.clubs[12])');
  h.run('CDFranceCareer.ensureAISheet(S.clubs[12]);validateCareer(S)');const after=h.state(),added=after.clubs[12].players.at(-1);
  assert.equal(h.seed(),rng);assert.deepEqual(after.clubs[12].players.slice(0,-1),before.clubs[12].players);assert.deepEqual(after.clubs[0],before.clubs[0]);
  assert.deepEqual(after.clubs.map(c=>c.cash),before.clubs.map(c=>c.cash));assert.deepEqual(after.history,before.history);assert.deepEqual(after.ledger,before.ledger);
  assert.equal(added.id,'youth-12-1-500');assert.equal(added.salary,2000);assert.equal(added.contractEnd,3);assert.equal(added.injury,0);assert.equal(added.dev.minutes,0);assert.equal(added.dev.appearances,0);assert.equal(added.dev.careerMinutes,0);assert.deepEqual(added.dev.history,[]);
  assert.equal(h.run('aiRosterPayroll(S.clubs[12])'),payroll+2000,'the real future payroll includes the new salary');
  const event=after.aiRoster.events[0];assert.equal(event.kind,'emergency');assert.equal(event.playerId,added.id);assert.equal(event.fee,0);
  const ids=allPlayers(after).map(p=>p.id);assert.equal(new Set(ids).size,ids.length);
  h.run('CDFranceCareer.ensureAISheet(S.clubs[12])');assert.deepEqual(h.state(),after);assert.equal(h.seed(),rng);
  h.run('beginMatch();validateCareer(S)');qualified(h.state());
  // Eligibility is checked on managerSheet's final allocation, not just buildSheet.
  assert.equal(h.run('S.live.sheets.every((sh,side)=>sh.on.every((id,i)=>slotEligible(matchPlayer(S.live,side,id),i))&&sh.bench.every((id,i)=>benchEligible(matchPlayer(S.live,side,id),i)))'),true);
 });
 check('native kickoff covers its opponent only; incomplete human sheet rolls back',()=>{
  const h=harness(fixtures.get(5));h.run('S.clubs[11].players.filter(p=>p.pos===POS[0]).slice(1).forEach(p=>p.injury=2)');
  const before=h.state(),persisted=clone(fixtures.get(5));persisted.store['bdt-v1']=JSON.stringify(before);const b=copied('outside-pair',persisted);good(b,'begin_match');validateNative(b);const after=state(b);
  assert.deepEqual(after.clubs[11].players.map(p=>p.id),before.clubs[11].players.map(p=>p.id),'unrelated injured AI receives no reinforcement');assert.equal(after.clubs[12].players.length,before.clubs[12].players.length+1);assert.deepEqual(after.clubs[0].players.map(p=>p.id),before.clubs[0].players.map(p=>p.id));
  const human=harness(fixtures.get(5));human.run('club().players.filter(p=>p.pos===POS[0]).forEach(p=>p.injury=2);validateCareer(S)');const invalid=clone(fixtures.get(5));invalid.store['bdt-v1']=JSON.stringify(human.state());const refused=inspected('invalid-human',invalid),factory=refused.matchFactory(),bytes=fs.readFileSync(file('invalid-human')),own=state(refused);
  assert.equal(call(refused,'begin_match').ok,false);assert.equal(refused.matchFactory(),factory);assert.deepEqual(state(refused),own);assert.deepEqual(fs.readFileSync(file('invalid-human')),bytes);
 });
 check('existing eligible academy player is promoted before creating a new player',()=>{
  const h=harness(fixtures.get(5));h.run('var youth=academyPlayer(12,2,1,700);youth.age=18;youth.contractEnd=null;aiRosterAcademy(S.clubs[12]).players.push(youth);validateCareer(S)');
  const before=h.state(),rng=h.seed(),id=h.run('youth.id');h.run('CDFranceCareer.ensureAISheet(S.clubs[12]);validateCareer(S)');
  const after=h.state();assert.equal(after.clubs[12].players.length,before.clubs[12].players.length+1);assert.equal(after.clubs[12].players.at(-1).id,id);assert.equal(after.aiRoster.events[0].kind,'promote');assert.equal(after.clubs[12].players.at(-1).contractEnd,3);assert.equal(h.run('aiRosterAcademy(S.clubs[12]).players.length'),0);assert.equal(h.seed(),rng);
 });
 check('fallback IDs skip collisions in clubs, both academies, market and free agents',()=>{
  const h=harness(fixtures.get(5));h.run(`
   function reserved(serial,academy=false){var p=JSON.parse(JSON.stringify(S.clubs[1].players[10]));p.id='youth-12-1-'+serial;if(academy){p.age=18;p.academy=true;p.contractEnd=null;}return p;}
   S.clubs[1].players.push(reserved(500));aiRosterAcademy(S.clubs[1]).players.push(reserved(501,true));S.development.academy.push(reserved(502,true));S.market.push(reserved(503));S.economy.freeAgents.push(reserved(504));validateCareer(S);
   CDFranceCareer.ensureAISheet(S.clubs[12]);validateCareer(S);
  `);assert.equal(h.state().clubs[12].players.at(-1).id,'youth-12-1-505');const ids=allPlayers(h.state()).map(p=>p.id);assert.equal(new Set(ids).size,ids.length);
 });
 check('existing 40 promotion / 100 fallback limits stay in force',()=>{
  for(const [count,want] of [[39,40],[40,41],[99,100]]){
   const h=harness(fixtures.get(5));h.run(`while(S.clubs[12].players.length<${count}){var extra=JSON.parse(JSON.stringify(S.clubs[12].players[10]));extra.id='padding-'+S.clubs[12].players.length;S.clubs[12].players.push(extra);}var candidate=academyPlayer(12,2,1,700);candidate.age=18;candidate.contractEnd=null;aiRosterAcademy(S.clubs[12]).players.push(candidate);validateCareer(S);CDFranceCareer.ensureAISheet(S.clubs[12]);validateCareer(S)`);
   assert.equal(h.state().clubs[12].players.length,want);assert.equal(h.state().aiRoster.events[0].kind,count===39?'promote':'emergency');assert.equal(h.run('aiRosterAcademy(S.clubs[12]).players.length'),count===39?0:1);
  }
  const h=harness(fixtures.get(5));h.run("while(S.clubs[12].players.length<100){var extra=JSON.parse(JSON.stringify(S.clubs[12].players[10]));extra.id='padding-'+S.clubs[12].players.length;S.clubs[12].players.push(extra);}validateCareer(S)");
  const persisted=clone(fixtures.get(5));persisted.store['bdt-v1']=JSON.stringify(h.state());const b=copied('limit',persisted),bytes=fs.readFileSync(file('limit')),before=state(b);
  const rejected=call(b,'begin_match');assert.equal(rejected.ok,false);assert.match(rejected.error,/plafond de 100/);assert.deepEqual(state(b),before);assert.deepEqual(fs.readFileSync(file('limit')),bytes);assert.equal(profile('limit').seed,persisted.seed);
 });
 check('legacy inactive career neither migrates roster state nor throws a helper TypeError',()=>{
  const fresh=bridge('old-healthy-source',5);good(fresh,'new_career',{club:0});const healthy=profile('old-healthy-source'),healthyState=JSON.parse(healthy.store['bdt-v1']);delete healthyState.aiRosterVersion;delete healthyState.aiRoster;healthy.store['bdt-v1']=JSON.stringify(healthyState);
  const playable=copied('old-healthy',healthy);good(playable,'begin_match');validateNative(playable);assert.equal(state(playable).aiRoster,undefined);assert.equal(state(playable).aiRosterVersion,undefined);
  const persisted=clone(fixtures.get(5)),old=JSON.parse(persisted.store['bdt-v1']);delete old.aiRosterVersion;delete old.aiRoster;persisted.store['bdt-v1']=JSON.stringify(old);
  const b=copied('legacy',persisted),bytes=fs.readFileSync(file('legacy'));assert.equal(good(b,'snapshot').meta.profileError,'');
  const rejected=call(b,'begin_match');assert.equal(rejected.ok,false);assert.match(rejected.error,/données de carrière incohérentes/);assert.doesNotMatch(rejected.error,/TypeError|academies/);assert.deepEqual(state(b),old);assert.deepEqual(fs.readFileSync(file('legacy')),bytes);assert.equal(state(b).aiRoster,undefined);
  const text=good(b,'export').meta.exportText;good(b,'import',{text});assert.deepEqual(state(b),old);good(b,'shutdown');const reopened=bridge('legacy',1);assert.deepEqual(state(reopened),old);
 });
 check('fiction legacy live conversion does not recruit and module absence preserves its old contract',()=>{
  const h=harness(fixtures.get(5)),before=h.state();h.run('createRugbyMatch([0,12],{minute:12,score:[0,0],tries:[0,0],events:[],finished:false,used:[]})');assert.deepEqual(h.state(),before);
  const absent=harness(fixtures.get(5),{files:CORE_FILES.filter(f=>f!=='france-career.js')}),old=absent.state();absent.run('S.live=createRugbyMatch([0,12])');assert.deepEqual(absent.state().clubs,old.clubs);assert.equal(absent.state().live.sheets[1].bench[2],null);assert.throws(()=>absent.run('validateCareer(S)'),/données de carrière incohérentes/);
  // The previously supported France conversion keeps its existing coverage.
  const france=context(5);france.run("start(0,'france');var pair=CDFranceCompetition.currentFixtures(S).find(f=>!f.pair.includes(S.club)).pair;var opponent=S.clubs[pair[0]];opponent.players.filter(p=>p.pos===POS[2]).slice(1).forEach(p=>p.injury=2)");
  const count=france.run('opponent.players.length');france.run('createRugbyMatch(pair,{minute:12,score:[0,0],tries:[0,0],events:[],finished:false,used:[]})');assert.equal(france.run('opponent.players.length'),count+1);
 });
 check('no-shortage branch leaves S/RNG identical; France and common retain their existing sheets',()=>{
  const initial=context(5);initial.run('start(0)');const persisted={seed:initial.seed(),store:{'bdt-v1':JSON.stringify(initial.state())}};
  const present=harness(persisted),absent=harness(persisted,{files:CORE_FILES.filter(f=>f!=='france-career.js')});
  for(const h of [present,absent])h.run('S.live=createRugbyMatch([0,13]);validateCareer(S)');assert.deepEqual(present.state(),absent.state());assert.equal(present.seed(),absent.seed());
  for(const mode of ['france','common']){
   const b=bridge('compat-'+mode,5);good(b,'new_career',{mode,club:0});const before=state(b);good(b,'begin_match');validateNative(b);assert.deepEqual(state(b).clubs.map(c=>c.players.map(p=>p.id)),before.clubs.map(c=>c.players.map(p=>p.id)));
   good(b,'delegate');good(b,'finish_round');assert.equal(good(b,'snapshot').meta.week,1);const text=good(b,'export').meta.exportText;good(b,'import',{text});assert.equal(good(b,'export').meta.exportText,text);
  }
 });
 check('forged null/22 sheet remains rejected without state, disk or RNG mutation',()=>{
  const b=copied('strict',fixtures.get(5));good(b,'begin_match');const before=state(b),bytes=fs.readFileSync(file('strict')),rng=profile('strict').seed,doc=JSON.parse(good(b,'export').meta.exportText);
  doc.state.live.sheets[1].bench[2]=null;doc.state.live.sheets[1].nominated.pop();
  const h=context();h.ctx.forged=doc.state;assert.throws(()=>h.run('validateCareer(forged)'),/données de carrière incohérentes/);doc.checksum=h.run('saveChecksum(forged)');
  const rejected=call(b,'import',{text:JSON.stringify(doc)});assert.equal(rejected.ok,false);assert.match(rejected.error,/données de carrière incohérentes/);assert.deepEqual(state(b),before);assert.deepEqual(fs.readFileSync(file('strict')),bytes);assert.equal(profile('strict').seed,rng);
 });
 check('real failed disk write rolls back cover, training and RNG; retry matches the control',()=>{
  const b=copied('disk-failure',fixtures.get(5)),control=copied('disk-control',fixtures.get(5)),target=file('disk-failure'),bytes=fs.readFileSync(target),before=state(b);
  fs.renameSync(target,target+'.held');fs.mkdirSync(target);
  try{const rejected=call(b,'begin_match');assert.equal(rejected.ok,false);assert.match(rejected.error,/Écriture de sauvegarde impossible/);assert.deepEqual(state(b),before);assert.deepEqual(fs.readFileSync(target+'.held'),bytes);}finally{fs.rmdirSync(target);fs.renameSync(target+'.held',target);}
  assert.deepEqual(fs.readFileSync(target),bytes);good(b,'begin_match');good(control,'begin_match');assert.deepEqual(state(b),state(control));assert.equal(profile('disk-failure').seed,profile('disk-control').seed);
 });
 check('native coverage waits for scheduled recovery and adds no unnecessary player',()=>{
  const persisted=clone(fixtures.get(5)),s=JSON.parse(persisted.store['bdt-v1']),injured=s.clubs[12].players.find(p=>p.id==='p12-2-1700000000000');injured.injury=1;persisted.store['bdt-v1']=JSON.stringify(s);
  const b=copied('recover-first',persisted);good(b,'begin_match');validateNative(b);const after=state(b);assert.equal(after.clubs[12].players.find(p=>p.id===injured.id).injury,0);assert.equal(after.clubs[12].players.length,s.clubs[12].players.length);assert.deepEqual(after.aiRoster.events,s.aiRoster.events);
 });
 check('native match factory is restored after success, refusal, thrown cover, disk failure and no fixture',()=>{
  const success=inspected('inspected-success',fixtures.get(5)),original=success.matchFactory();good(success,'begin_match');assert.equal(success.matchFactory(),original);assert.equal(call(success,'begin_match').ok,false);assert.equal(success.matchFactory(),original);
  const h=harness(fixtures.get(5));h.run("while(S.clubs[12].players.length<100){var extra=JSON.parse(JSON.stringify(S.clubs[12].players[10]));extra.id='padding-'+S.clubs[12].players.length;S.clubs[12].players.push(extra);}validateCareer(S)");
  const capped=clone(fixtures.get(5));capped.store['bdt-v1']=JSON.stringify(h.state());const fail=inspected('inspected-cover-error',capped),beforeFactory=fail.matchFactory(),before=state(fail),bytes=fs.readFileSync(file('inspected-cover-error'));
  assert.match(call(fail,'begin_match').error,/plafond de 100/);assert.equal(fail.matchFactory(),beforeFactory);assert.deepEqual(state(fail),before);assert.deepEqual(fs.readFileSync(file('inspected-cover-error')),bytes);
  const disk=inspected('inspected-disk-error',fixtures.get(5)),diskFactory=disk.matchFactory(),target=file('inspected-disk-error');fs.renameSync(target,target+'.held');fs.mkdirSync(target);
  try{assert.match(call(disk,'begin_match').error,/Écriture de sauvegarde impossible/);assert.equal(disk.matchFactory(),diskFactory);}finally{fs.rmdirSync(target);fs.renameSync(target+'.held',target);}
  const noMatch=context(5);noMatch.run('start(13);while(S.phase==="league")finishRound();validateCareer(S)');assert.equal(noMatch.run('!!nextMatch()'),false);assert.notEqual(noMatch.state().phase,'ended');
  noMatch.run('var aiClub=S.clubs[roundPairs()[0][0]];aiClub.players.filter(p=>p.pos===POS[2]).slice(1).forEach(p=>p.injury=2);validateCareer(S)');
  const idle=inspected('inspected-no-fixture',{protocol:1,seed:noMatch.seed(),clock:1700000000000,store:{'bdt-v1':JSON.stringify(noMatch.state())}}),idleFactory=idle.matchFactory(),rosters=state(idle).clubs.map(c=>c.players.map(p=>p.id));
  good(idle,'begin_match');assert.equal(idle.matchFactory(),idleFactory);assert.deepEqual(state(idle).clubs.map(c=>c.players.map(p=>p.id)),rosters);assert.equal(state(idle).live,null);
 });
 const report={passed:true,seeds:[1,5],checks,limitations:['23 is the internal engine format, not a universal law','academy reinforcement remains a management abstraction','no Godot UI or Windows executable reception']};
 if(process.env.CD_NATIVE_SHEET_REPORT)fs.writeFileSync(process.env.CD_NATIVE_SHEET_REPORT,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));
}finally{for(const b of bridges)b.close();fs.rmSync(root,{recursive:true,force:true});}
