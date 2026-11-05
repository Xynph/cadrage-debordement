'use strict';
const assert=require('node:assert/strict');
const api=require('../dist/espoirs-strategy-v95-v100.js');
function make(){
 const p=(id,pos,age,rate,potential)=>({id,name:id,pos,age,rating:rate,fam:1,condition:85,injury:0,
  dev:{potential,xp:0,seasonStart:rate}});
 return {season:1,club:0,round:4,phase:'league',live:false,
  development:{academy:[p('a','10',18,62,85),p('b','9',19,61,80)]},
  clubs:[{name:'Maison',cash:200000,players:[p('senior','10',24,76,78)]},
   {name:'Rival',cash:10000,players:[]}],v73Espoirs:{results:[],minutes:{}},
  v77Promotions:{promotions:[],history:[]},v78to81:{loans:[]}};
}
const s=make();
assert.equal(api.ensure(s).version,1);
assert.equal(api.valid(s.v95to100),true);
const cash=s.clubs[0].cash;
assert.equal(api.discover(s,'Bretagne',()=>false),false,'rollback scouting');
assert.equal(s.clubs[0].cash,cash);
assert.equal(api.discover(s,'Bretagne',()=>true),true);
assert.equal(s.v95to100.candidates.length,3);
assert.equal(api.discover(s,'Bretagne',()=>true),true);
assert.equal(api.discover(s,'Bretagne',()=>true),true);
assert.equal(api.discover(s,'Bretagne',()=>true),false,'scouting cap');
const c=s.v95to100.candidates[0],initial=s.development.academy.length;
assert.equal(api.recruit(s,c.id,()=>false),false,'recruit rollback');
assert.equal(s.development.academy.length,initial);
assert.equal(api.recruit(s,c.id,()=>true),true,'native-shaped youth added');
assert.equal(s.development.academy.length,initial+1);
assert.equal(api.recruit(s,c.id,()=>true),false,'no double recruit');
assert.equal(api.meeting(s,()=>false),false);
assert.equal(api.meeting(s,()=>true),true);
assert.equal(s.v95to100.cohesion,64);
assert.equal(api.load(s,'a','intensive',()=>false),false);
assert.equal(api.load(s,'a','intensive',()=>true),true);
assert.equal(api.ambition(s,'a','professionnel',()=>true),true);
assert.equal(api.ambition(s,'a','professionnel',()=>true),false);
assert.equal(api.identity(s,'defense',()=>true),true);
assert.equal(api.identity(s,'unknown',()=>true),false);
const before=s.development.academy.find(p=>p.id==='a').rating;
s.phase='ended';
assert.equal(api.settle(s),true);
assert.equal(api.settle(s),false,'year end only once');
assert.ok(s.development.academy.find(p=>p.id==='a').rating>=before+1);
assert.ok(s.v95to100.history[0].styleProgress>=1,'style modifies development');
assert.equal(s.v95to100.history.length,1);
assert.equal(s.v95to100.history[0].broken,1);
assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v95to100),true,'serialized state valid');
const legacy=make();delete legacy.v95to100;assert.ok(api.ensure(legacy),'old saves supported');
const bad=make();bad.v95to100={version:8};assert.equal(api.ensure(bad),null,'invalid state rejected');
for(let year=2;year<=17;year++){
 s.season=year;s.phase='league';api.ensure(s);
 assert.equal(api.valid(s.v95to100),true,'rolled season '+year);
 assert.equal(s.v95to100.scouts,0);
 s.phase='ended';assert.equal(api.settle(s),true);
}
assert.equal(s.v95to100.history.length,15,'bounded history');
assert.equal(api.valid(s.v95to100),true);
assert.ok(api.panel(s).includes('V95–V100'));
assert.ok(api.panel(s).includes('v95Scout'));
assert.ok(api.panel(s).includes('v97Load'));
assert.ok(api.panel(s).includes('v98Ambition'));
console.log('V95-V100 PASS: scouting/recruitment rollback, cohesion, training, ambition, identity, reputation, old saves, 17 seasons');
