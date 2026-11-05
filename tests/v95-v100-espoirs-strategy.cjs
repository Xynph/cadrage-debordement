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
const n=api.network(s.v95to100,s);
assert.equal(n.feeders.length,16,'sixteen original amateur clubs');
assert.equal(n.recruiters.length,3,'recruiters cover local and international regions');
assert.equal(n.players.length,32,'persistent player pool');
assert.equal(n.players.filter(x=>x.scouted>0).length,3,'regional observation discovers local players');
assert.equal(api.discover(s,'Bretagne',()=>true),true);
assert.equal(api.discover(s,'Bretagne',()=>true),true);
assert.equal(api.discover(s,'Bretagne',()=>true),false,'scouting cap');
const c=n.players.find(x=>x.region==='Bretagne'&&x.scouted>0);
assert.equal(api.recruit(s,c.id,()=>true),false,'cannot sign without scouting and trial');
assert.equal(api.watch(s,c.id,()=>true),true,'second report');
assert.ok(s.v95to100.network.players.find(x=>x.id===c.id).lastReport.reliability>=75);
assert.equal(api.trial(s,c.id,()=>false),false,'trial rollback');
assert.equal(api.trial(s,c.id,()=>true),true);
const initial=s.development.academy.length;
assert.equal(api.recruit(s,c.id,()=>false),false,'offer rollback');
assert.equal(s.development.academy.length,initial);
const score=api.model(s,c,n);
assert.ok(score.interest>=0&&score.interest<=100,'well bounded prospect decision');
assert.equal(api.recruit(s,c.id,()=>true),true,'offer resolved once (accept or decline)');
const decisionState=s.v95to100.network.players.find(x=>x.id===c.id).status;
assert.ok(['recruited','declined'].includes(decisionState));
if(decisionState==='recruited'){
 assert.equal(s.development.academy.length,initial+1,'new youth joins native academy');
 assert.equal(s.development.academy.find(x=>x.id===c.id).trainingOrigin.clubId,c.clubId);
}else assert.equal(s.development.academy.length,initial,'young player refuses and stays away');
assert.equal(api.recruit(s,c.id,()=>true),false,'no duplicate');
const foreign=s.v95to100.network.players.find(x=>x.union!=='FR'&&x.age<18);
assert.ok(foreign,'underage foreign prospect exists');
foreign.scouted=2;foreign.trial=true;
assert.equal(api.recruit(s,foreign.id,()=>true),false,'no international minor fast-track');
const adult=s.v95to100.network.players.find(x=>x.union!=='FR'&&x.age>=18);
assert.ok(adult,'foreign adult prospect exists');
adult.scouted=2;adult.trial=true;
assert.ok(api.panel(s).includes('v95Clearance'),'clearance control offered for eligible foreign adult');
assert.equal(api.recruit(s,adult.id,()=>true),false,'international clearance must be recorded');
assert.equal(api.clearance(s,adult.id,()=>false),false,'clearance rollback');
assert.equal(api.clearance(s,adult.id,()=>true),true,'simulated administrative receipt');
assert.equal(api.recruit(s,adult.id,()=>true),true,'post-clearance offer handled');
assert.equal(api.partner(s,n.feeders[0].id,()=>false),false,'partnership rollback');
assert.equal(api.partner(s,n.feeders[0].id,()=>true),true);
assert.equal(api.partner(s,n.feeders[0].id,()=>true),false,'partnership cannot duplicate');
assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v95to100),true,'new network persists in save');
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

const credits=make();
const cn=api.ensure(credits).network;
const promoted=cn.players.find(p=>p.union==='FR');
const originalFeederAge=promoted.age;
promoted.status='recruited';
credits.v77Promotions.promotions=[{playerId:promoted.id,season:1}];
credits.phase='ended';assert.equal(api.settle(credits),true);
assert.equal(credits.v95to100.network.credits.length,1,'RIF descriptive credit after promotion');
assert.equal(credits.v95to100.network.credits[0].club,promoted.clubId,'original training club retained');
credits.season=2;credits.phase='league';api.ensure(credits);
assert.equal(credits.v95to100.network.players.find(x=>x.id===promoted.id).age,originalFeederAge+1,
 'feeder ages with season');
credits.phase='ended';assert.equal(api.settle(credits),true);
assert.equal(credits.v95to100.network.credits.length,2,'annual credit, no fake cash payment');
assert.equal(api.valid(credits.v95to100),true,'feeder network survives season');

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
assert.ok(api.panel(s).includes('v95Watch'));
assert.ok(api.panel(s).includes('v95Trial'));
assert.ok(api.panel(s).includes('v95Partner'));
console.log('V95-V100 PASS: scouting/recruitment rollback, cohesion, training, ambition, identity, reputation, old saves, 17 seasons');
