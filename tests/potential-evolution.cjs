'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const create=require('../native/engine/potential-evolution.cjs');
function fixture(id='young',traits=90){
 const p={id,name:id,pos:'Centre',fam:7,age:20,rating:70,condition:95,injury:0,physicalLoad:{fatigue:10},hiddenTraitsV2:{professionalism:traits,ambition:traits,adaptability:traits},dev:{potential:76,lastYear:0}};
 const other={...structuredClone(p),id:'opponent'};
 const s={season:1,round:0,club:0,careerVariation:{seed:41},clubs:[{id:0,players:[p]},{id:1,players:[other]}],development:{academy:[]}};
 return {p,s,e:create()};
}
function season(f,{work='normal',condition=95,matches=true,injured=false}={}){
 for(let week=0;week<26;week++){
  f.s.round=week;f.p.condition=condition;f.p.injury=injured&&week<16?1:0;
  f.e.training(f.s,f.p,work);
  if(matches&&week<12&&!f.p.injury)f.e.match(f.s,{finished:true,pair:[0,1],score:[30,10],sheets:[{used:[f.p.id],minutes:{[f.p.id]:80}},{used:['opponent'],minutes:{opponent:80}}],events:[]});
 }
}
test('sustained good work and performances can raise a young ceiling without guaranteeing it or raising current ability',()=>{
 let up=0,stable=0;
 for(let i=0;i<100;i++){
  const f=fixture('young-'+i);season(f);f.p.rating=72;
  const level=f.p.rating,traits=structuredClone(f.p.hiddenTraitsV2),result=f.e.review(f.s,f.p,1,20);
  assert.ok([0,1,2].includes(result.delta));assert.equal(f.p.rating,level);assert.deepEqual(f.p.hiddenTraitsV2,traits);
  assert.equal(f.p.dev.potential,76+result.delta);result.delta?up++:stable++;
  const once=JSON.stringify(f.s);f.e.review(f.s,f.p,1,20);assert.equal(JSON.stringify(f.s),once);
 }
 assert.ok(up>0&&stable>0,'breakthrough and no breakthrough both exist');
});
test('personality changes development opportunities for otherwise identical seasons',()=>{
 let high=0,low=0;
 for(let i=0;i<120;i++)for(const [traits,key]of [[90,'high'],[20,'low']]){
  const f=fixture('same-'+i,traits);season(f);f.p.rating=72;const result=f.e.review(f.s,f.p,1,20);
  if(key==='high')high+=result.delta;else low+=result.delta;
 }
 assert.ok(high>low&&low>=0);
});
test('lack of opportunities or injury alone does not lower the ceiling; prolonged poor work can',()=>{
 let down=0;
 for(let i=0;i<100;i++){
  const poor=fixture('poor-'+i,20),injured=fixture('injured-'+i,20),unused=fixture('unused-'+i,20);
  for(let year=1;year<=2;year++)for(const [f,options]of [[poor,{matches:false,condition:25}],[injured,{matches:false,condition:25,injured:true}],[unused,{matches:false}]]){
   f.s.season=year;season(f,options);const result=f.e.review(f.s,f.p,year,19+year);
   if(f===poor&&year===1)assert.equal(result.delta,0);
   if(f!==poor)assert.equal(result.delta,0);
   if(f===poor&&result.delta<0)down++;
  }
 }
 assert.ok(down>0);
});
test('actual participation matters; no data or single performance cannot create a breakthrough',()=>{
 const f=fixture();assert.equal(f.e.review(f.s,f.p,1,20).delta,0);assert.equal(f.s.potentialEvolution,undefined);
 f.e.training(f.s,f.p,'normal');f.e.match(f.s,{finished:true,pair:[0,1],score:[80,0],sheets:[{used:[f.p.id],minutes:{[f.p.id]:0}},{used:[],minutes:{}}],events:[]});
 assert.equal(f.e.review(f.s,f.p,1,20).delta,0);assert.equal(f.p.dev.potential,76);
});
test('state is strict, bounded and projected only as qualitative information',()=>{
 const f=fixture();season(f);f.p.rating=72;f.e.review(f.s,f.p,1,20);
 assert.equal(f.e.validate(f.s),true);const before=JSON.stringify(f.s);
 const view=f.e.project(f.s,f.p.id);assert.ok(['up','stable','down'].includes(view.trend));assert.equal(view.potential,undefined);assert.equal(JSON.stringify(f.s),before);
 const bad=structuredClone(f.s);bad.potentialEvolution.records[0][0].push(0);assert.throws(()=>f.e.validate(bad),/Potentiel évolutif/);
 const other=structuredClone(f.s);other.potentialEvolution.extra=true;assert.throws(()=>f.e.validate(other),/Potentiel évolutif/);
});
test('sporting contributions are the same in presented and AI matches, including save and resume',()=>{
 const outcomes=[];
 for(const userSide of [0,-1]){
  const f=fixture('same-player'),l={userSide,finished:false,pair:[0,1],possession:0,score:[20,20],sheets:[{on:[f.p.id],used:[f.p.id],minutes:{[f.p.id]:80}},{on:['opponent'],used:['opponent'],minutes:{opponent:80}}],events:[]};
  f.e.action(l,'play',{kind:'turnover',team:0,actor:f.p.id});
  f.s.live=structuredClone(l);assert.equal(f.e.validate(f.s),true);
  f.e.action(f.s.live,'try',{team:0,actor:f.p.id});f.s.live.finished=true;
  f.e.match(f.s,f.s.live);outcomes.push(f.s.potentialEvolution.records);
 }
 assert.deepEqual(outcomes[0],outcomes[1]);
});
test('extra-time participants remain in exposure and mismatched team contributions are rejected',()=>{
 const f=fixture(),l={finished:false,pair:[0,1],score:[20,20],sheets:[{on:[f.p.id],used:[f.p.id],minutes:{[f.p.id]:110}},{on:['opponent'],used:['opponent'],minutes:{opponent:110}}],events:[]};
 f.e.action(l,'try',{team:0,actor:f.p.id});f.s.live=l;assert.equal(f.e.validate(f.s),true);
 const invalid=structuredClone(f.s);invalid.live.potentialEvidence.rows[0][0]='opponent';assert.throws(()=>f.e.validate(invalid),/équipe/);
 l.finished=true;f.e.match(f.s,l);assert.equal(f.s.potentialEvolution.records[0].find(r=>r[0]===f.p.id)[8],110);
});
test('academy centre slots use the actual selected players rather than senior club IDs',()=>{
 const f=fixture(),guest={...structuredClone(f.p),id:'guest-player'};
 const result={pair:[30,40],score:[24,10]},teams=[[f.p],[guest]];
 f.e.academyMatch(f.s,result,teams);const once=JSON.stringify(f.s);
 f.e.academyMatch(f.s,result,teams);assert.equal(JSON.stringify(f.s),once);
 assert.ok(f.s.potentialEvolution.records.flat().some(r=>r[0]==='guest-player'&&r[8]===80));
});
