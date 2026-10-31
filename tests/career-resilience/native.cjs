'use strict';
// Test utilities only: execute the native harness; never write a user's save.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {context}=require('../harness.cjs');
const ROOT=path.resolve(__dirname,'../..');
const BASE_SHA='3655df2302d2f2ccbe37674ef473bb96cb91c6f5';
const clone=x=>JSON.parse(JSON.stringify(x));
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const data=(g,expression='S')=>JSON.parse(g.run('JSON.stringify('+expression+')'));
function sources(){
 const files=fs.readdirSync(path.join(ROOT,'dist')).filter(x=>x.endsWith('.js')).map(x=>'dist/'+x).concat('tests/harness.cjs','tests/career-resilience/native.cjs','ci/career-resilience-run.cjs').sort();
 const hashes=Object.fromEntries(files.map(f=>[f,hash(fs.readFileSync(path.join(ROOT,f)))]));
 return {digest:hash(JSON.stringify(hashes)),hashes};
}
function setRng(g,rng){
 assert.ok(rng&&Number.isInteger(rng.value)&&rng.value>=0&&rng.value<=0xffffffff&&Number.isSafeInteger(rng.calls)&&rng.calls>=0,'Invalid test RNG sidecar');
 g.ctx.__resilienceRng=clone(rng);
 g.run('Math.random=()=>{const r=__resilienceRng;r.value=(Math.imul(r.value,1664525)+1013904223)>>>0;r.calls++;return r.value/4294967296}');
 return g;
}
function rng(g){return clone(g.ctx.__resilienceRng);}
function fresh(clubId=0,seed=827381){
 const g=setRng(context(),{value:seed,calls:0});
 g.run('start('+clubId+')');assert.equal(g.run('managerMobilityEnable()'),true);
 return g;
}
function restore(document,random,storage){
 // Use the actual parser AND confirmed import, not just JSON.parse.
 const g=context(undefined,storage);g.ctx.__incoming=JSON.stringify(document);
 g.run('pendingSave=parseSaveDocument(__incoming)');
 assert.equal(g.run('confirmSaveImport()'),true,'Native import rejected');
 assert.deepEqual(data(g),document.state,'Import changed the saved career');
 return setRng(g,random);
}
function capture(g){return {document:data(g,'createSaveDocument()'),rng:rng(g)};}
function fork(g,storage){const s=capture(g);return restore(s.document,s.rng,storage);}
function check(stats,label,fn){
 try{const value=fn();stats.passed++;stats.byCheck[label]=(stats.byCheck[label]||0)+1;return value;}
 catch(e){stats.failed.push({label,error:e.message});throw e;}
}
function newStats(){return {passed:0,failed:[],byCheck:{},reloads:0,replayComparisons:0};}
function verified(g,stats,label){
 return check(stats,label,()=>{
  const doc=data(g,'createSaveDocument()');g.ctx.__verify=JSON.stringify(doc);
  assert.equal(g.run('parseSaveDocument(__verify).checksum'),doc.checksum);
  assert.equal(doc.state.clubs.length,14);
  assert.ok(doc.state.clubs.every(c=>Number.isFinite(c.cash)));
  assert.ok(doc.state.worldManagement.clubInfo.every(c=>Number.isFinite(c.debt)&&c.debt>=0&&c.facilities>=1&&c.facilities<=10&&c.reputation>=0&&c.reputation<=100));
  assert.ok(g.run('S.lineup.filter(Boolean).every(id=>club().players.some(p=>p.id===id))'));
  assert.ok(Buffer.byteLength(JSON.stringify(doc),'utf8')<=5*1024*1024);
  return doc;
 });
}
function reload(g,stats,label){const doc=verified(g,stats,label);const restored=restore(doc,rng(g));stats.reloads++;return restored;}
function round(g,stats){
 const previous=data(g,'({club:S.club,cash:club().cash,round:S.round,phase:S.phase,season:S.season})');
 g.run('globalThis.__ledgerBefore=new Set(S.ledger)');
 g.run('finishRound()');
 const created=data(g,'S.ledger.filter(e=>!__ledgerBefore.has(e))');delete g.ctx.__ledgerBefore;
 check(stats,'native-round-ledger-reconciliation',()=>{
  assert.equal(g.run('S.club'),previous.club);
  assert.equal(g.run('club().cash'),previous.cash+created.reduce((n,e)=>n+e.amount,0));
  assert.ok(g.run('S.round')!==previous.round||g.run('S.phase')!==previous.phase,'Round did not progress');
 });
 return created;
}
function academies(s){return s.clubs.map(c=>({id:c.id,players:(c.id===s.club?s.development.academy:s.aiRoster.academies.find(a=>a.clubId===c.id).players).map(p=>p.id).sort()}));}
function players(s){return s.clubs.map(c=>({id:c.id,players:c.players.map(p=>({id:p.id,salary:p.salary,contractEnd:p.contractEnd})).sort((a,b)=>a.id.localeCompare(b.id))}));}
function moveCompared(g,target,stats){
 const before=data(g),from=before.club,year=before.season,id='job-'+year+'-'+target;
 check(stats,'native-application-and-appointment',()=>{
  assert.equal(g.run('managerMobilityApply('+target+')'),true);
  assert.equal(g.run('managerMobilityAccept('+JSON.stringify(id)+')'),true);
  assert.equal(g.run('S.club'),from,'Appointment moved manager early');
 });
 g=reload(g,stats,'pending-appointment-roundtrip');
 const control=fork(g),expectedArchive=before.managerMobility.archives.find(a=>a.clubId===target);
 assert.equal(control.run('managerMobilityCancel()'),true);
 control.run('advanceSeason()');g.run('advanceSeason()');
 const a=data(g),b=data(control);
 check(stats,'handover-cash-professionals-and-installations',()=>{
  assert.equal(a.club,target);assert.equal(a.season,year+1);assert.equal(a.managerMobility.pending,null);
  assert.deepEqual(a.clubs.map(c=>c.cash),b.clubs.map(c=>c.cash));
  assert.deepEqual(players(a),players(b));
  assert.deepEqual(a.worldManagement.clubInfo.map(c=>[c.facilities,c.debt,c.reputation]),b.worldManagement.clubInfo.map(c=>[c.facilities,c.debt,c.reputation]));
  assert.deepEqual(academies(a),academies(b));
  assert.deepEqual(a.worldManagement.yearbook,b.worldManagement.yearbook);
 });
 check(stats,'handover-archives-and-single-coach-owner',()=>{
  const archived=a.managerMobility.archives.find(x=>x.clubId===from);
  assert.deepEqual(archived.ledger,b.ledger);
  assert.deepEqual(a.ledger,expectedArchive?expectedArchive.ledger:[]);
  assert.deepEqual(a.careerManagement.boardHistory,expectedArchive?expectedArchive.boardHistory:[]);
  assert.equal(a.worldManagement.clubInfo[from].coachChanges,b.worldManagement.clubInfo[from].coachChanges+1);
  assert.equal(a.worldManagement.clubInfo[target].coachChanges,Math.max(b.worldManagement.clubInfo[target].coachChanges,before.worldManagement.clubInfo[target].coachChanges+1));
  assert.equal(a.managerMobility.history.length,before.managerMobility.history.length+1);
  assert.equal(a.coachCareer,undefined);assert.equal(a.coachContracts,undefined);
 });
 return reload(g,stats,'post-handover-roundtrip');
}
function controlledTarget(g,target,adjustments){
 // Fixture intervention, recorded individually; not a natural market outcome.
 const before=data(g);const w=before.worldManagement.clubInfo[target];
 const nextCash=Math.max(before.clubs[target].cash,w.debt+2000000);
 adjustments.push({season:before.season,clubId:target,reason:'controlled-return-boundary',cashBefore:before.clubs[target].cash,cashAfter:nextCash,cashInjection:nextCash-before.clubs[target].cash,trustBefore:before.trust,ownReputationBefore:before.worldManagement.clubInfo[before.club].reputation,targetConfidenceBefore:w.coachConfidence});
 g.run('S.trust=100;worldClub(S.club).reputation=100;worldClub('+target+').coachConfidence=0;S.clubs['+target+'].cash='+nextCash);
 assert.equal(g.run('managerMobilityDecision('+target+').accepted'),true);
}
function seal(payload){return {format:'cd-test-career-checkpoint',version:1,checksum:hash(JSON.stringify(payload)),payload};}
function unseal(envelope){
 assert.equal(envelope?.format,'cd-test-career-checkpoint');assert.equal(envelope.version,1);
 assert.equal(envelope.checksum,hash(JSON.stringify(envelope.payload)),'Corrupt test checkpoint');
 assert.ok(envelope.payload&&envelope.payload.sourceDigest===sources().digest,'Native sources changed between segments');
 return envelope.payload;
}
module.exports={ROOT,BASE_SHA,clone,hash,data,sources,setRng,rng,fresh,restore,capture,fork,check,newStats,verified,reload,round,academies,players,moveCompared,controlledTarget,seal,unseal};
