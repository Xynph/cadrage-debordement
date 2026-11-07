'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const source=read('dist/lnr-ratings-v12.js');
const active=vm.runInNewContext(source+'\n;LNR_V12_PLAYER_DATA;');
const aging=vm.runInNewContext(read('dist/lnr-v11-aging.js')+'\n;LNR_V11_AGE;');
const report=JSON.parse(read('data/scouting/potential-trajectory-v14-20261107.json'));
const cl=(n,a,b)=>Math.max(a,Math.min(b,n));
const mean=a=>a.reduce((s,x)=>s+x,0)/a.length;
const quick=['acceleration','topSpeed','agility','explosiveness','jumping'];
const mental=['decisions','anticipation','vision','composure'];
function mapped(tuple,descriptor,ceiling){
 return {id:descriptor.playerId,gameplayPosition:descriptor.role,potential:ceiling,
  hiddenTraitsV2:JSON.parse(JSON.stringify(tuple[6])),
  attributesV2:Object.fromEntries(active.attributeKeys.map((k,i)=>[k,tuple[3][i]]))};
}
function shape(p,age){
 const vals=p.attributesV2;
 return {age,
  quick:mean(quick.map(k=>vals[k])),
  mental:mean(mental.map(k=>vals[k])),
  strength:vals.strength,
  speed:vals.topSpeed,
  decisions:vals.decisions,
  average:mean(Object.values(vals))};
}
function shadow(descriptor,variant){
 const tuple=active.players[descriptor.playerId];
 const ceiling=variant==='career'?descriptor.annualCurveCeiling:tuple[2];
 let p=mapped(tuple,descriptor,ceiling);
 const inputBefore=JSON.stringify(p);
 const timeline=[];
 for(let age=18;age<=40;age++){
  timeline.push(shape(p,age));
  const result=aging.step(p,{playerId:p.id,age,season:age-17,lastSeason:null},
   {minutes:1600,training:1,injuryWeeks:0,load:0});
  assert.equal(result.state.age,age+1);
  assert.equal(result.state.season,age-17);
  assert.equal(result.state.lastSeason,age-17);
  assert.equal(result.player.potential,ceiling);
  assert.equal(p.id,result.player.id);
  for(const v of Object.values(result.player.attributesV2)) assert.ok(Number.isFinite(v)&&v>=20&&v<=97);
  p=result.player;
 }
 assert.equal(timeline.length,23);
 assert.equal(JSON.stringify(mapped(tuple,descriptor,ceiling)),inputBefore,'Source attributes must remain untouched');
 return timeline;
}
test('1592 potential rebases, exactly 47 with zero growth room',()=>{
 const ids=Object.keys(active.players);
 assert.equal(ids.length,1592);
 assert.equal(new Set(ids).size,1592);
 assert.match(read('dist/lnr-career.js'),/p\.dev\.potential=clamp\(p\.rating\+Math\.max\(0,oldPotential-oldRating\),p\.rating,99\)/);
 assert.match(read('dist/development.js'),/const virtualPotential=clamp\(Math\.max\(p\.rating,d\.potential\),20,97\)/);
 const data=ids.map(id=>{
  const [rating,oldRating,oldPotential]=active.players[id];
  const rebased=cl(rating+Math.max(0,oldPotential-oldRating),rating,99);
  return {id,rating,rebased};
 });
 assert.equal(data.filter(x=>x.rebased<x.rating).length,0);
 assert.equal(data.filter(x=>x.rebased===x.rating).length,47);
 assert.equal(data.filter(x=>x.rebased>x.rating).length,1545);
 assert.equal(report.summary.zeroRoom,47);
 assert.equal(report.summary.careerPotentialBelowActive,0);
 assert.equal(report.summary.positiveRoom,1545);
 console.log('RUGBY_REAL_CAREER_POTENTIAL '+JSON.stringify({players:data.length,zeroRoom:47,positiveRoom:1545,negativeRoom:0}));
});
test('40 priority candidates reproduce active rebase and leave source ratings unchanged',()=>{
 assert.equal(report.priority.length,40);
 assert.equal(new Set(report.priority.map(p=>p.playerId)).size,40);
 assert.ok(report.priority.every(p=>p.ratingChange===0&&p.potentialChange===0));
 for(const p of report.priority){
  const tuple=active.players[p.playerId];assert.ok(tuple,p.playerId);
  const [rating,oldRating,oldPotential]=tuple;
  const expected=cl(rating+Math.max(0,oldPotential-oldRating),rating,99);
  assert.equal(p.activeRating,rating);
  assert.equal(p.historicalRating,oldRating);
  assert.equal(p.historicalPotential,oldPotential);
  assert.equal(p.careerPotential,expected);
  assert.equal(p.remainingRoom,expected-rating);
  assert.equal(p.annualCurveCeiling,cl(Math.max(rating,expected),20,97));
  assert.equal(p.action,expected===rating?'review-zero-room':'preserve-rebased-room');
 }
 assert.equal(report.priority.filter(p=>p.remainingRoom===0).length,7);
});
test('40 profiles x 23 ages x 2 scenarios: true V11 step no double evolution or source mutation',()=>{
 const results=[];
 for(const p of report.priority){
  const effective=shadow(p,'career'),historical=shadow(p,'historical');
  const at=(arr,age)=>arr.find(t=>t.age===age);
  const prior=at(effective,30),later=at(effective,40);
  const old=at(historical,40);
  assert.ok(at(effective,40).speed<=at(effective,30).speed,p.playerId+' decline topSpeed age 30->40');
  assert.ok(at(effective,40).quick<at(effective,30).quick,p.playerId+' decline quickness age 30->40');
  assert.ok(Math.abs(later.mental-prior.mental)<Math.abs(later.quick-prior.quick)+1,p.playerId+' mental more durable than physical');
  assert.ok(Number.isFinite(old.average));
  results.push({id:p.playerId,role:p.role,league:p.division,zeroRoom:p.remainingRoom===0,quickLoss30to40:prior.quick-later.quick,mentalChange30to40:later.mental-prior.mental,effectiveAverage40:later.average,historicalAverage40:old.average,delta40:later.average-old.average});
 }
 const changed=results.filter(r=>Math.abs(r.delta40)>1e-6).length;
 const quickDrop=mean(results.map(x=>x.quickLoss30to40));
 const mentalDrift=mean(results.map(x=>x.mentalChange30to40));
 assert.ok(quickDrop>0);
 assert.ok(quickDrop>Math.abs(mentalDrift));
 console.log('RUGBY_REAL_SHADOW_18_40 '+JSON.stringify({players:results.length,agePoints:23,scenarios:2,yearlySteps:40*23*2,zeroRoom:results.filter(x=>x.zeroRoom).length,changedAt40:changed,quickDrop30to40:+quickDrop.toFixed(3),mentalChange30to40:+mentalDrift.toFixed(3),averageDifference40:+mean(results.map(x=>x.delta40)).toFixed(3)}));
});
test('yearly V11 step cannot be applied twice in the same season',()=>{
 for(const p of report.priority){
  const profile=mapped(active.players[p.playerId],p,p.annualCurveCeiling);
  const output=aging.step(profile,{playerId:profile.id,age:30,season:13},{minutes:1600,training:1});
  const repeated=aging.step(output.player,{...output.state,age:31,season:13,lastSeason:13},{minutes:1600,training:1});
  assert.equal(JSON.stringify(repeated.player),JSON.stringify(output.player));
  assert.equal(repeated.changes.length,0);
 }
});
