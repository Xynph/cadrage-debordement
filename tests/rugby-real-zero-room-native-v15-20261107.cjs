'use strict';
/**
 * V15: observational-only test of the 47 V12 players with zero rebased rating room.
 * Uses actual new-career construction, native rounds/season transitions and signed
 * save-document import/export. Never changes production player data.
 */
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const DIST=path.resolve(__dirname,'../dist');
const MODULES=['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'];
function boot(saved){
 const g=context(saved);
 for(const f of MODULES)vm.runInContext(fs.readFileSync(path.join(DIST,f),'utf8'),g.ctx,{filename:f});
 return g;
}
function read(g,expression){return JSON.parse(g.run('JSON.stringify('+expression+')'))}
function roundtrip(g){
 const document=read(g,'createSaveDocument()');
 const next=boot();
 next.ctx.__v15SaveDocument=document;
 next.run('S=parseSaveDocument(JSON.stringify(__v15SaveDocument)).state');
 assert.equal(next.run('!!S&&S.lnrMode?.version===1'),true,'native LNR mode survives import');
 return next;
}
const data=vm.runInNewContext(fs.readFileSync(path.join(DIST,'lnr-ratings-v12.js'),'utf8')+'\n;LNR_V12_PLAYER_DATA;');
const zeros=Object.entries(data.players).filter(([,t])=>t[2]<=t[1]).map(([id,t])=>({id,initial:t[0],legacyRating:t[1],legacyPotential:t[2]}));
const zeroIDs=zeros.map(x=>x.id);
function roster(g){
 return read(g,`S.clubs.flatMap(c=>c.players.filter(p=>p.lnrRatingsVersion===1).map(p=>({
  id:p.id,club:c.slug||c.name,age:p.age,rating:p.rating,roleNote:roleNote(p),potential:p.dev?.potential,
  minutes:p.dev?.careerMinutes??0,historyCount:p.dev?.history?.length??0,
  strength:p.attributesV2?.strength,topSpeed:p.attributesV2?.topSpeed,
  decisions:p.attributesV2?.decisions,skillMean:Object.values(p.skills||{}).reduce((s,v)=>s+v,0)/11,condition:p.condition
 })))`);
}
function teamRatings(g){
 return read(g,`S.clubs.map(c=>{
  const s=buildSheet(c),map=new Map(c.players.map(p=>[p.id,p]));
  const starters=s.lineup.filter(Boolean).map(id=>map.get(id));
  const bench=s.bench.filter(Boolean).map(id=>map.get(id));
  const avg=arr=>arr.length?Math.round(arr.reduce((n,p)=>n+roleNote(p),0)/arr.length*100)/100:null;
  return {name:c.name,roster:c.players.length,lnr:c.players.filter(p=>p.lnrRatingsVersion===1).length,
   startingPlayers:starters.length,benchPlayers:bench.length,xv:avg(starters),bench:avg(bench),
   xvIds:starters.map(p=>p.id),rosterIds:c.players.map(p=>p.id)};
 })`);
}

test('All 47 zero-room identifiers come from active V12 tuples, without altering them',()=>{
 assert.equal(Object.keys(data.players).length,1592);
 assert.equal(zeros.length,47);
 assert.equal(new Set(zeroIDs).size,47);
 assert.ok(zeros.every(x=>x.legacyPotential<=x.legacyRating));
 const room=Object.entries(data.players).map(([id,t])=>({id,room:Math.max(0,t[2]-t[1])}));
 assert.equal(room.filter(x=>x.room===0).length,47);
 assert.equal(room.filter(x=>x.room>0).length,1545);
 console.log('RUGBY_REAL_V15_ZERO_COHORT '+JSON.stringify({total:47,identifiers:zeroIDs}));
});
test('Native LNR seasons, signed save roundtrips and player movement: longitudinal zero-room observation',{timeout:240000},()=>{
 const sourceSignature=JSON.stringify(data.players);
 let g=boot();
 g.run("start(0,'lnr')");
 assert.equal(g.run("aiRosterActive()"),true,"native AI roster is already active at career start");
 const baseRoster=roster(g);
 const baseMap=new Map(baseRoster.map(p=>[p.id,p]));
 const seen=baseRoster.filter(p=>zeroIDs.includes(p.id));
 assert.ok(seen.length>0,'at least one zero-room profile must instantiate in TOP14');
 assert.ok(seen.every(p=>p.potential===p.rating),'career initializer must preserve zero room');
 const topIDs=seen.map(p=>p.id);
 const outside=zeroIDs.filter(id=>!baseMap.has(id));
 const observations=new Map(topIDs.map(id=>[id,[]]));
 const seasons=[];
 const teamSnapshots=[{season:1,clubs:teamRatings(g)}];
 const aiReports=[];
 let transfers=0,departures=0,retirements=0,otherExits=0;
 const exited=new Set();
 for(let year=1;year<=6;year++){
  assert.equal(g.run('S.season'),year);
  assert.equal(g.run('S.phase'),'league');
  for(let round=0;round<26;round++){
   assert.equal(g.run('S.round'),round);
   assert.equal(g.run('roundPairs().length'),7);
   g.run('finishRound()');
  }
  let guard=0;
  while(g.run('S.phase')!=='ended'){
   assert.ok(++guard<=4,'native playoffs must finish');
   g.run('finishRound()');
  }
  const seasonPlayers=roster(g),seasonMap=new Map(seasonPlayers.map(p=>[p.id,p]));
  assert.equal(new Set(seasonPlayers.map(p=>p.id)).size,seasonPlayers.length);
  for(const id of topIDs){
   const p=seasonMap.get(id);
   if(p) {
    assert.ok(Number.isFinite(p.potential)&&Number.isFinite(p.rating));
    assert.ok(Number.isFinite(p.topSpeed)&&Number.isFinite(p.strength)&&Number.isFinite(p.decisions));
    observations.get(id).push({season:year,phase:'end',...p});
   }else observations.get(id).push({season:year,phase:'absent'});
  }
  const yearReports=read(g,'S.aiRoster.reports.filter(x=>x.season===S.season)');
  aiReports.push({season:year,clubs:yearReports.map(x=>({clubId:x.clubId,renewed:x.renewed||0,released:x.released||0,
   retired:x.retired||0,recruited:x.recruited||0,promoted:x.promoted||0,emergency:x.emergency||0}))});
  seasons.push({season:year,remaining:topIDs.filter(id=>seasonMap.has(id)).length,
   lnrPlayers:seasonPlayers.length});
  g.run('advanceSeason()');
  assert.equal(g.run('S.season'),year+1);
  g=roundtrip(g);
  assert.equal(g.run('aiRosterActive()'),true,'native AI roster state preserved by signed save');
  teamSnapshots.push({season:year+1,clubs:teamRatings(g)});
  const next=roster(g),nextMap=new Map(next.map(p=>[p.id,p]));
  for(const id of topIDs){
   const before=seasonMap.get(id),after=nextMap.get(id);
   if(before&&!after){
    departures++;exited.add(id);
    const retired=read(g,'S.development.retired.map(p=>p.id)').includes(id);
    if(retired)retirements++;else otherExits++;
   }
   if(before&&after&&before.club!==after.club)transfers++;
   if(after){
    assert.ok(Number.isFinite(after.rating)&&Number.isFinite(after.potential));
    assert.ok(Number.isFinite(after.topSpeed)&&Number.isFinite(after.strength)&&Number.isFinite(after.decisions));
    observations.get(id).push({season:year+1,phase:'after-advance-import',...after});
   }else observations.get(id).push({season:year+1,phase:'after-advance-import',absent:true});
  }
 }
 assert.equal(JSON.stringify(data.players),sourceSignature,'V12 source must never mutate');
 assert.equal(teamSnapshots.length,7);
 const trajectory=teamSnapshots.map((snapshot,index)=>{
  const q=snapshot.clubs.map(c=>c.xv),ai=snapshot.clubs.slice(1),prior=index?new Map(teamSnapshots[index-1].clubs.map(c=>[c.name,c])):null;
  return {season:snapshot.season,clubCount:snapshot.clubs.length,xvMean:+(q.reduce((a,b)=>a+b,0)/q.length).toFixed(2),
   xvMin:Math.min(...q),xvMax:Math.max(...q),
   aiXvMean:+(ai.reduce((s,c)=>s+c.xv,0)/ai.length).toFixed(2),
   aiXvMin:Math.min(...ai.map(c=>c.xv)),aiXvMax:Math.max(...ai.map(c=>c.xv)),
   playerClubXV:snapshot.clubs[0].xv,playerClubRoster:snapshot.clubs[0].roster,
   originalPlayers:snapshot.clubs.reduce((s,c)=>s+c.lnr,0),
   totalPlayers:snapshot.clubs.reduce((s,c)=>s+c.roster,0),
   rosterInflow:prior?snapshot.clubs.reduce((s,c)=>s+c.rosterIds.filter(id=>!prior.get(c.name).rosterIds.includes(id)).length,0):0,
   rosterOutflow:prior?snapshot.clubs.reduce((s,c)=>s+prior.get(c.name).rosterIds.filter(id=>!c.rosterIds.includes(id)).length,0):0,
   incompleteSheets:snapshot.clubs.filter(c=>c.startingPlayers!==15||c.benchPlayers!==8).length};
 });
 const aiTotals=aiReports.flatMap(x=>x.clubs).reduce((a,r)=>{
  for(const k of Object.keys(a))a[k]+=r[k]||0;return a;
 },{renewed:0,released:0,retired:0,recruited:0,promoted:0,emergency:0});
 console.log('RUGBY_REAL_V15_NATIVE_TOP14_SQUAD_EVOLUTION '+JSON.stringify({years:6,aiRosterEnabled:true,
  aiTotals,annualAiTransactions:aiReports.map(x=>({season:x.season,recruited:x.clubs.reduce((n,r)=>n+r.recruited,0),
   renewed:x.clubs.reduce((n,r)=>n+r.renewed,0),released:x.clubs.reduce((n,r)=>n+r.released,0),
   promoted:x.clubs.reduce((n,r)=>n+r.promoted,0)})),
  seasonSnapshots:trajectory,
  clubStartEnd:teamSnapshots[0].clubs.map(c=>{const last=teamSnapshots.at(-1).clubs.find(x=>x.name===c.name);
   return {club:c.name,initialXV:c.xv,lastXV:last.xv,xvDelta:+(last.xv-c.xv).toFixed(2),
    initialBench:c.bench,lastBench:last.bench,initialOriginal:c.lnr,lastOriginal:last.lnr};}),
  note:'Native TOP14 only; 13 AI-managed clubs reported separately from unattended player-managed club; no playable PRO D2 seasons'}));
 const profiles=topIDs.map(id=>{
  const history=observations.get(id);
  const first=baseMap.get(id);
  const present=history.filter(p=>Number.isFinite(p.rating));
  const last=present.at(-1)||first;
  return {id,initialAge:first.age,initialRating:first.rating,initialRoleNote:first.roleNote,initialPotential:first.potential,
   initialSpeed:first.topSpeed,initialStrength:first.strength,initialDecisions:first.decisions,initialSkillMean:first.skillMean,
   lastAge:last.age,lastRating:last.rating,lastRoleNote:last.roleNote,lastPotential:last.potential,
   lastSpeed:last.topSpeed,lastStrength:last.strength,lastDecisions:last.decisions,lastSkillMean:last.skillMean,
   observations:history};
 });
 console.log('RUGBY_REAL_V15_NATIVE_ZERO_ROOM '+JSON.stringify({
  seasons:6,savesAndImports:6,initialTop14:topIDs.length,
  uninstantiatedInTop14:outside.length,players:profiles,
  seasonCounts:seasons,clubTransfersObserved:transfers,rosterExitsObserved:departures,
  confirmedRetirements:retirements,otherExits,uniqueExitedPlayers:exited.size,
  skillMeanDrift:profiles.filter(x=>x.lastAge>x.initialAge).map(x=>({id:x.id,ageYears:x.lastAge-x.initialAge,
    ratingChange:x.lastRating-x.initialRating,roleNoteChange:x.lastRoleNote-x.initialRoleNote,
    skillMeanChange:+(x.lastSkillMean-x.initialSkillMean).toFixed(3)})),
  diagnosticOnly:true,noDataChanges:true
 }));
});

