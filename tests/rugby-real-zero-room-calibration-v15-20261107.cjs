'use strict';
/**
 * V15 comparative laboratory: native V11 ageing on shadow copies only.
 * This deliberately DOES NOT write proposed potential overrides into gameplay.
 * Real ages + existing active 36 attributes, no fabricated 18-year-old histories.
 */
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {context}=require('./harness.cjs');
const dist=path.resolve(__dirname,'../dist');
const src=file=>fs.readFileSync(path.join(dist,file),'utf8');
const catalogue=vm.runInNewContext(src('lnr-ratings-v12.js')+'\n;LNR_V12_PLAYER_DATA;');
const runtime=vm.runInNewContext(src('lnr-v11-aging.js')+'\n;({step:LNR_V11_AGE.step,project:lnrProjectV12})');
const bootstrap=context();
for(const file of ['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'])
 vm.runInContext(src(file),bootstrap.ctx,{filename:file});
const roster=JSON.parse(bootstrap.run(`JSON.stringify(LNR_CATALOGUE.clubs.flatMap(c=>c[3].map(p=>({id:p[0],league:c[1],age:lnrBirthAge(p[0]).age,club:c[0]}))))`));
const facts=new Map(roster.map(p=>[p.id,p]));
const keys=catalogue.attributeKeys;
const zeros=Object.entries(catalogue.players).filter(([,t])=>t[2]<=t[1]).map(([id])=>id);
const mean=a=>a.length?a.reduce((x,y)=>x+y,0)/a.length:null;
const round=x=>x===null?null:+x.toFixed(3);
function profile(id,delta){
 const t=catalogue.players[id],o={};
 for(let i=0;i<keys.length;i++)o[keys[i]]=t[3][i];
 const careerPotential=Math.min(97,t[0]+Math.max(0,t[2]-t[1])+delta);
 return {id,gameplayPosition:t[5],attributesV2:o,hiddenTraitsV2:JSON.parse(JSON.stringify(t[6])),
  potential:Math.max(20,careerPotential)};
}
function scenario(id,add,activity,years=6){
 const person=facts.get(id);assert.ok(person,'missing LNR identity '+id);
 let p=profile(id,add);
 const starting=JSON.stringify(p),initialSkill=runtime.project(p);
 const initial={rating:catalogue.players[id][0],skills:initialSkill,attributes:{...p.attributesV2}};
 for(let y=0;y<years;y++){
  const evolved=runtime.step(p,{playerId:id,age:person.age+y,season:y+1,lastSeason:null},
   {minutes:activity===0?0:activity,training:activity===0?0:1,injuryWeeks:0,load:0});
  p=evolved.player;
  assert.ok(Object.values(p.attributesV2).every(v=>Number.isFinite(v)&&v>=20&&v<=97));
 }
 const lastSkill=runtime.project(p),deltaSkill=mean(Object.values(lastSkill))-mean(Object.values(initialSkill));
 assert.equal(JSON.stringify(profile(id,add)),starting,'shadow must not mutate source');
 return {id,age:person.age,league:person.league,role:p.gameplayPosition,oldPotential:catalogue.players[id][2],
  rating:initial.rating,projectedRating:Math.max(20,Math.min(97,Math.round(initial.rating+deltaSkill))),
  speedStart:initial.attributes.topSpeed,speedEnd:p.attributesV2.topSpeed,
  strengthStart:initial.attributes.strength,strengthEnd:p.attributesV2.strength,
  decisionsStart:initial.attributes.decisions,decisionsEnd:p.attributesV2.decisions,
  projectedSkillShift:round(deltaSkill),skillSpeedChange:round(lastSkill.speed-initialSkill.speed),
  quickLoss:round(initial.attributes.topSpeed-p.attributesV2.topSpeed)};
}
test('Exhaustive 1592 ages and zero-room stratification: no assumed youth history',()=>{
 assert.equal(roster.length,1592);
 assert.equal(facts.size,1592);
 assert.equal(zeros.length,47);
 const cohort=zeros.map(id=>({...facts.get(id),id}));
 assert.ok(cohort.every(p=>p&&Number.isInteger(p.age)));
 const byLeague=Object.fromEntries(['top14','prod2'].map(league=>{
  const group=cohort.filter(p=>p.league===league);
  return [league,{n:group.length,youngUnder26:group.filter(p=>p.age<=25).length,ages:group.map(p=>p.age).sort((a,b)=>a-b)}];
 }));
 console.log('RUGBY_REAL_V15_AGE_CENSUS '+JSON.stringify({
  zeroTotal:47,byLeague,allAgeRanges:{
   youngUnder26:roster.filter(x=>x.age<=25).length,
   mature26to29:roster.filter(x=>x.age>=26&&x.age<=29).length,
   veteran30plus:roster.filter(x=>x.age>=30).length
  },zeroPlayers:cohort
 }));
});
test('Six shadow years x 47 zero-room players: baseline vs +2/+4 room and no-exposure vs full-exposure',()=>{
 const tuples=Object.entries(catalogue.players).map(([id,t])=>({id,t,room:Math.max(0,t[2]-t[1])}));
 const untouched=JSON.stringify(catalogue.players);
 const records=[];
 for(const id of zeros){
  const base=scenario(id,0,1600);
  const up2=scenario(id,2,1600);
  const up4=scenario(id,4,1600);
  const idle=scenario(id,0,0);
  records.push({id,league:base.league,role:base.role,age:base.age,
   baseRating:base.rating,baselineProjectedRating:base.projectedRating,
   bonus2ProjectedRating:up2.projectedRating,bonus4ProjectedRating:up4.projectedRating,
   baselineSpeedLoss:base.quickLoss,idleSpeedLoss:idle.quickLoss,
   strengthChange:round(base.strengthEnd-base.strengthStart),
   decisionsChange:round(base.decisionsEnd-base.decisionsStart),
   baselineSkillChange:base.projectedSkillShift,
   bonus2SkillGain:round(up2.projectedSkillShift-base.projectedSkillShift),
   bonus4SkillGain:round(up4.projectedSkillShift-base.projectedSkillShift)});
 }
 assert.equal(JSON.stringify(catalogue.players),untouched,'active data is read only');
 const stats={cohort:47,shadowYears:6,variantsPerPlayer:4,annualTransitions:47*6*4,
  bonus2RatingMovers:records.filter(x=>x.bonus2ProjectedRating!==x.baselineProjectedRating).length,
  bonus4RatingMovers:records.filter(x=>x.bonus4ProjectedRating!==x.baselineProjectedRating).length,
  meanBonus2SkillGain:round(mean(records.map(x=>x.bonus2SkillGain))),
  meanBonus4SkillGain:round(mean(records.map(x=>x.bonus4SkillGain))),
  meanSpeedLoss:round(mean(records.map(x=>x.baselineSpeedLoss))),
  meanIdleSpeedLoss:round(mean(records.map(x=>x.idleSpeedLoss))),
  meanDecisionsChange:round(mean(records.map(x=>x.decisionsChange))),
  ageBands:Object.fromEntries(['under26','26to29','30plus'].map(k=>{
   const rows=records.filter(x=>k==='under26'?x.age<=25:k==='26to29'?x.age>=26&&x.age<=29:x.age>=30);
   return [k,{n:rows.length,bonus4RatingMovers:rows.filter(x=>x.bonus4ProjectedRating!==x.baselineProjectedRating).length,
    speedLoss:round(mean(rows.map(x=>x.baselineSpeedLoss)))}];
  }))
 };
 console.log('RUGBY_REAL_V15_CALIBRATION_COMPARE '+JSON.stringify({stats,records}));
});
test('Full active cohort natural-age exercise: baseline exposure and two alternative potentials against age-band survival bias',()=>{
 const untouched=JSON.stringify(catalogue.players);
 const rows=[];
 for(const id of Object.keys(catalogue.players)){
  const baseline=scenario(id,0,1600,4);
  const uplift=scenario(id,3,1600,4);
  const dormant=scenario(id,0,0,4);
  rows.push({id,age:baseline.age,role:baseline.role,league:baseline.league,
   zero:zeros.includes(id),ratingDelta:baseline.projectedRating-baseline.rating,
   upliftRatingDelta:uplift.projectedRating-baseline.projectedRating,
   speedDelta:round(baseline.speedEnd-baseline.speedStart),
   idleSpeedDelta:round(dormant.speedEnd-dormant.speedStart),
   mentalDelta:round(baseline.decisionsEnd-baseline.decisionsStart)});
 }
 assert.equal(rows.length,1592);
 assert.equal(JSON.stringify(catalogue.players),untouched);
 const buckets=['under26','26to29','30to34','35plus'];
 const groups=Object.fromEntries(buckets.map(k=>{
  const subset=rows.filter(x=>k==='under26'?x.age<=25:k==='26to29'?x.age<=29&&x.age>=26:k==='30to34'?x.age>=30&&x.age<=34:x.age>=35);
  return [k,{n:subset.length,meanRatingDelta:round(mean(subset.map(x=>x.ratingDelta))),
   meanUpliftRatingDelta:round(mean(subset.map(x=>x.upliftRatingDelta))),
   meanSpeedDelta:round(mean(subset.map(x=>x.speedDelta))),
   meanIdleSpeedDelta:round(mean(subset.map(x=>x.idleSpeedDelta))),
   meanDecisionsDelta:round(mean(subset.map(x=>x.mentalDelta)))}];
 }));
 const divisions=Object.fromEntries(['top14','prod2'].map(l=>{
  const subset=rows.filter(x=>x.league===l);
  return [l,{n:subset.length,meanRatingDelta:round(mean(subset.map(x=>x.ratingDelta))),
   upliftMovers:subset.filter(x=>x.upliftRatingDelta!==0).length,
   meanSpeedDelta:round(mean(subset.map(x=>x.speedDelta)))}];
 }));
 const roles=Object.fromEntries([...new Set(rows.map(x=>x.role))].map(role=>{
  const subset=rows.filter(x=>x.role===role);
  return [role,{n:subset.length,meanRatingDelta:round(mean(subset.map(x=>x.ratingDelta))),
   meanSpeedDelta:round(mean(subset.map(x=>x.speedDelta)))}];
 }));
 console.log('RUGBY_REAL_V15_ALL_PLAYER_SHADOW '+JSON.stringify({
  profiles:1592,years:4,scenarios:3,annualTransitions:1592*4*3,
  ageBands:groups,divisions,roles,
  caveat:'Fixed initial 2026 roster, no retirement/transfer; observational shadow ageing, not simulated multi-division careers'
 }));
});
