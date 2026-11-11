'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const makeVariation=require('../native/engine/career-variation.cjs');
const keys=['pass','tackle','ruck','carry','kick','speed','power','lineout','scrum','stamina','mental'];
const attributes=['passing','receiving','offload','tackling','jackal','ruckClearout','ballCarry','evasion','kickDistance','kickAccuracy','goalAccuracy','ballHandling','decisions','anticipation','vision','positioning','composure','discipline','teamwork','leadership','workRate','acceleration','topSpeed','agility','explosiveness','strength','endurance','jumping','scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul','kickChase','aerialAbility'];
const engine=makeVariation({roleNote:p=>Math.round(keys.reduce((sum,key)=>sum+p.skills[key]+p.rating-p.skillBase,0)/keys.length),
 projectSkills:p=>Object.fromEntries(keys.map((key,index)=>[key,p.attributesV2[attributes[index]]]))});
const source=id=>({id,name:'Profil de recette',pos:'Centre',fam:7,age:24,rating:60,skillBase:60,potential:78,
 skills:Object.fromEntries(keys.map(key=>[key,60])),attributesV2:Object.fromEntries(attributes.map(key=>[key,60])),
 dev:{potential:80,seasonStart:60,xp:0},rosterProfile:{position:{primary:'Centre'}},hiddenTraitsV2:{professionalism:70}});

test('bounded variations are concentrated around zero and stable by ID independent of iteration order',()=>{
 const config=engine.settings(813),ids=Array.from({length:10000},(_,i)=>'qa:'+i);
 const draws=ids.map(id=>engine.deltas(config,id));
 assert.ok(draws.every(d=>Number.isInteger(d.potential)&&Math.abs(d.potential)<=5&&Number.isInteger(d.current)&&Math.abs(d.current)<=3));
 assert.ok(draws.filter(d=>Math.abs(d.potential)<=1).length>6300);
 assert.ok(draws.filter(d=>Math.abs(d.current)<=1).length>8000);
 assert.ok(draws.some(d=>Math.abs(d.potential)===5)&&draws.some(d=>Math.abs(d.current)===3));
 for(let i=0;i<100;i++)assert.deepEqual(engine.deltas(config,ids[i]),engine.deltas(config,ids.slice().reverse().find(id=>id===ids[i])));
 assert.notDeepEqual(draws.slice(0,100),ids.slice(0,100).map(id=>engine.deltas(engine.settings(814),id)));
});

test('disabling current-level variation keeps every quality unchanged but still changes potential',()=>{
 const config=engine.settings(813,false);
 const id=Array.from({length:100},(_,i)=>'qa:'+i).find(id=>engine.deltas(config,id).potential!==0);
 const original=source(id),before=JSON.stringify(original),changed=engine.player(original,config),delta=engine.deltas(config,id).potential;
 for(const key of ['rating','skillBase','skills','attributesV2','rosterProfile','hiddenTraitsV2','id','pos','fam'])assert.deepEqual(changed[key],original[key]);
 assert.equal(changed.dev.potential,original.dev.potential+delta);
 assert.equal(changed.potential,original.potential+delta);
 assert.equal(JSON.stringify(original),before);
});

test('actual full and compact qualities move with the level, with caps above the current ability',()=>{
 const config=engine.settings(17);
 const id=Array.from({length:100},(_,i)=>'qa:'+i).find(id=>engine.deltas(config,id).current!==0);
 const original=source(id),delta=engine.deltas(config,id),changed=engine.player(original,config);
 assert.equal(changed.rating-original.rating,delta.current);
 assert.ok(Object.values(changed.attributesV2).every(value=>value===60+delta.current));
 assert.ok(Object.values(changed.skills).every(value=>value===60+delta.current));
 assert.equal(changed.skillBase-changed.rating,original.skillBase-original.rating);
 assert.equal(changed.dev.potential-original.dev.potential,delta.potential);
 assert.equal(changed.potential-original.potential,delta.potential);
 const packed=source(id);delete packed.attributesV2;packed.nativeAttributesV1='60'.repeat(36);
 const compact=engine.player(packed,config);
 assert.equal(compact.nativeAttributesV1,String(60+delta.current).repeat(36));
 assert.ok(Object.values(compact.skills).every(value=>value===60+delta.current));
 for(const rating of [15,20,97,99]){
  const p=source(id);p.rating=p.skillBase=rating;p.dev.potential=rating;p.potential=Math.min(97,Math.max(20,rating));
  p.skills=Object.fromEntries(keys.map(key=>[key,rating]));p.attributesV2=Object.fromEntries(attributes.map(key=>[key,Math.min(97,Math.max(20,rating))]));
  const varied=engine.player(p,config);
  assert.ok(varied.rating>=15&&varied.rating<=99&&Math.abs(varied.rating-rating)<=3);
  assert.ok(varied.dev.potential>=varied.rating&&varied.dev.potential<=99&&Math.abs(varied.dev.potential-rating)<=5);
  assert.ok(Object.values(varied.attributesV2).every(value=>value>=20&&value<=97));
 }
});

test('initial populations, market copies and coaching references vary once without any RNG draw',()=>{
 const professional=source('qa:professional'),free=source('qa:free');
 const state={season:1,round:0,clubs:[{players:[professional]}],development:{academy:[source('qa:youth')]},economy:{freeAgents:[free]},market:[structuredClone(free)],
  v90to94:{profiles:[{id:professional.id,startRating:60,baseline:60}]}};
 const config=engine.settings(42),random=Math.random;
 Math.random=()=>{throw Error('No RNG allowed');};
 try{
  engine.apply(state,config);
  assert.deepEqual(state.market[0],state.economy.freeAgents[0]);
  assert.equal(state.v90to94.profiles[0].startRating,state.clubs[0].players[0].rating);
  const once=JSON.stringify(state);
  engine.apply(state,{varyCurrent:true,seed:42,version:1});
  assert.equal(JSON.stringify(state),once);
  assert.throws(()=>engine.apply(state,engine.settings(43)),/contradictoires/);
 }finally{Math.random=random;}
});

test('manifest types, bounds, unknown fields and creation phase are strictly checked',()=>{
 for(const config of [{version:2,seed:1,varyCurrent:true},{version:1,seed:-1,varyCurrent:true},{version:1,seed:4294967296,varyCurrent:true},
  {version:1,seed:1.5,varyCurrent:true},{version:1,seed:1,varyCurrent:'false'},{version:1,seed:1,varyCurrent:false,potential:false},null])assert.throws(()=>engine.validate(config));
 assert.deepEqual(engine.settings(0),{version:1,seed:0,varyCurrent:true});
 assert.throws(()=>engine.apply({season:2,round:0},engine.settings(42)),/création/);
});
