'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {ATTRIBUTES,PROFILES,ROLE_WEIGHTS,baseline,assess,build,defaultRoster}=require('../tools/lnr-ratings-v1.cjs');

const sample=(more={})=>({id:'lnr:123',name:'Joueur Test',club:'clermont',league:'top14',position:'Demi de mêlée',birthYear:1999,...more});
function evidence(metrics){
  return {season:'2025-2026',url:'https://top14.lnr.fr/joueur/example',observedThrough:'2026-06-30',metrics:{minutesPlayed:1240,...metrics}};
}
test('11 attributes and exact 1592 validated existing LNR IDs, no roster mutation',()=>{
  const original=defaultRoster(),before=JSON.stringify(original),result=build(original);
  assert.equal(result.ratings.length,1592);
  assert.equal(result.quality.total,1592);
  assert.equal(result.quality.readyForGame,0);
  assert.equal(result.readyForGame,false);
  assert.equal(result.quality.priorOnly,1592);
  assert.equal(new Set(result.ratings.map(p=>p.id)).size,1592);
  assert.equal(JSON.stringify(original),before);
  for(const r of result.ratings){
    assert.deepEqual(Object.keys(r.attributes),ATTRIBUTES);
    assert(Object.values(r.attributes).every(v=>Number.isInteger(v)&&v>=30&&v<=95));
    assert(Number.isInteger(r.roleRating)&&r.roleRating>=30&&r.roleRating<=95);
    assert.equal(r.confidence,'low');
    assert.equal(r.stage,'candidate-not-authorized-for-gameplay');
  }
});
test('reproducible: IDs do not cause random quality differences',()=>{
  const a=assess(sample()),b=assess(sample({id:'lnr:999',name:'Autre joueur'}));
  assert.deepEqual(a.attributes,b.attributes);
  assert.equal(a.roleRating,b.roleRating);
});
test('role weights are valid and profile groups cover catalogue',()=>{
  for(const [group,weights] of Object.entries(ROLE_WEIGHTS)){
    assert(PROFILES[group]);
    assert(Object.entries(weights).every(([k,w])=>ATTRIBUTES.includes(k)&&w>0));
  }
  const groupSet=new Set(defaultRoster().map(p=>p.position));
  for(const group of groupSet)assert(PROFILES[group],group);
});
test('specific stats change only linked attributes and keep sourced evidence',()=>{
  const x=sample();
  const prior=assess(x);
  const result=assess(x,evidence({tacklesMade:140,tacklesAttempted:150,passes:330,goalsMade:90,goalsAttempted:110,penaltiesConceded:8,kicksInPlay:150}));
  assert(result.metricsApplied>=4);
  assert.equal(result.confidence,'medium-provisional');
  assert(result.attributes.tackle>prior.attributes.tackle);
  assert(result.attributes.pass>prior.attributes.pass);
  assert.equal(result.attributes.scrum,prior.attributes.scrum);
  assert.equal(result.sources.tackle.season,'2025-2026');
});
test('rejects future data, invalid ratios and suspicious evidence',()=>{
  assert.throws(()=>assess(sample(),{...evidence({}),season:'2026-2027'}),/2025-26/);
  assert.throws(()=>assess(sample(),{...evidence({}),observedThrough:'2026-11-01'}),/Future information/);
  assert.throws(()=>assess(sample(),evidence({tacklesMade:101,tacklesAttempted:90})),/exceeds/);
  assert.throws(()=>assess(sample(),evidence({passes:-1})),/Invalid metric/);
  assert.throws(()=>build([sample(),sample()]),/Duplicate/);
});
test('weak evidence does not fabricate a performance adjustment',()=>{
  const result=assess(sample(),evidence({minutesPlayed:160,tacklesMade:30,tacklesAttempted:40}));
  assert.equal(result.metricsApplied,0);
  assert.equal(result.evidenceStatus,'positional-prior-only');
  assert(result.warnings.some(w=>/Insufficient/.test(w)));
});
test('age uncertain on October roster is not used as a verified July age',()=>{
  const player=sample({birthYear:undefined,ageReported:27});
  assert.equal(baseline(player).age,null);
});
test('athletic stereotypes and nationality do not modify rating',()=>{
  const a=assess(sample({nationality:'France',heightCm:175,weightKg:72}));
  const b=assess(sample({nationality:'Fidji',heightCm:210,weightKg:135}));
  assert.deepEqual(a.attributes,b.attributes);
  assert.equal(a.roleRating,b.roleRating);
});
