'use strict';
const assert=require('node:assert/strict');
const api=require('../dist/espoirs-dynamics-v90-v94.js');
function setup(){return {season:1,round:12,phase:'league',live:false,club:0,
development:{academy:[{id:'y-1',name:'Aube',pos:'10',age:19,rating:68,condition:92,dev:{potential:90}},
{id:'y-2',name:'Brume',pos:'9',age:20,rating:72,condition:89,dev:{potential:88}}]},
clubs:[{name:'Local',cash:100000,players:[{id:'p-1',name:'Ciel',age:23,pos:'10',rating:76,condition:89,dev:{potential:79}}]},
{name:'Rival A',cash:100000,players:[]},{name:'Rival B',cash:100000,players:[]}],
v73Espoirs:{minutes:{'y-1':560,'y-2':400}},v77Promotions:{promotions:[],history:[]},v78to81:{loans:[],history:[]}}}
const s=setup();assert.equal(api.ensure(s).version,1);
assert.equal(api.valid(s.v90to94),true);
assert.deepEqual(api.revelations(s).map(x=>x.id).sort(),['y-1','y-2']);
const offer=api.offers(s)[0];
if(offer){const initial=s.clubs[0].cash;
assert.equal(api.retain(s,offer.id,offer.clubs[0].club,()=>false),false);
assert.equal(s.clubs[0].cash,initial,'save failure rolls back cash');
assert.equal(api.retain(s,offer.id,offer.clubs[0].club,()=>true),true);
assert.ok(s.clubs[0].cash<initial);
assert.equal(api.retain(s,offer.id,offer.clubs[0].club,()=>true),false,'no duplicate');
}
assert.equal(api.specialize(s,'y-1','vitesse',()=>false),false,'save rollback');
assert.equal(s.v90to94.events.some(x=>x.type==='specialisation'),false);
assert.equal(api.specialize(s,'y-1','vitesse',()=>true),true);
assert.equal(api.specialize(s,'y-1','technique',()=>true),true);
assert.equal(api.specialize(s,'y-1','puissance',()=>true),true);
assert.equal(api.specialize(s,'y-1','endurance',()=>true),false,'load cap');
assert.equal(api.specialize(s,'y-2','danger',()=>true),false);
assert.equal(api.interview(s,'y-2','promouvoir',()=>true),true);
assert.equal(api.interview(s,'y-2','promouvoir',()=>true),false,'one promise');
const morale=s.v90to94.profiles.find(x=>x.id==='y-2').morale;
s.phase='ended';assert.equal(api.seasonEnd(s),true);
assert.equal(api.seasonEnd(s),false,'annual settlement exactly once');
assert.ok(s.development.academy[0].rating>68,'training raises rating');
assert.ok(s.development.academy[0].condition<92,'fatigue tradeoff');
assert.ok(s.v90to94.profiles.find(x=>x.id==='y-2').morale<morale,'broken promise matters');
assert.equal(s.v90to94.history.length,1);
assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v90to94),true,'save JSON');
assert.equal(api.ensure(setup()).version,1,'legacy save');
s.season=2;s.phase='league';api.ensure(s);
for(let y=2;y<17;y++){s.phase='ended';assert.equal(api.seasonEnd(s),true,'year '+y);
s.season=y+1;s.phase='league';api.ensure(s)}
assert.equal(s.v90to94.history.length,12,'bounded career history');
assert.equal(api.valid(s.v90to94),true,'long-run valid');
assert.ok(api.panel(s).includes('V90–V94'));
assert.ok(api.panel(s).includes('v92Specialize'));
assert.ok(api.panel(s).includes('v93Interview'));
assert.equal(api.install({}),false,'no global game installed');
const invalid=setup();invalid.v90to94={version:99};
assert.equal(api.ensure(invalid),null,'corrupt save rejected');
console.log('V90-V94 PASS: discoveries, rivalry, retention rollback, specialization fatigue, promises, saves, long seasons, UI actions');
