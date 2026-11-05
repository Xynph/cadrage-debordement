'use strict';
const assert=require('node:assert/strict');
const api=require('../dist/espoirs-followup-v86-v89.js');
function state(){
 const young={id:'youth-a',name:'Aube',pos:'10',age:19,rating:62,dev:{potential:84}};
 const pro={id:'youth-b',name:'Brume',pos:'10',age:22,rating:70,dev:{potential:80}};
 return {season:1,round:10,club:0,live:false,phase:'league',
   development:{academy:[young]},clubs:[{name:'Maison',players:[pro]},
     {name:'Accueil A',players:[{id:'a',pos:'10',rating:60}]},
     {name:'Accueil B',players:[{id:'b',pos:'10',rating:90},{id:'c',pos:'10',rating:87}]}],
   v73Espoirs:{minutes:{'youth-a':400}},v77Promotions:{promotions:[{playerId:'youth-b',season:1}],history:[]},
   v78to81:{loans:[],history:[]}};
}
const s=state();
globalThis.CDEspoirsPathwaysV78V81={eligiblePro:x=>x.clubs[x.club].players};
assert.equal(api.ensure(s).version,1);
assert.equal(api.valid(s.v86to89),true);
assert.equal(api.target(s,'youth-a',800,()=>false),false,'save rollback');
assert.equal(s.v86to89.targets.length,0,'no target persisted on failure');
assert.equal(api.target(s,'youth-a',800,()=>true),true);
assert.equal(api.target(s,'youth-a',1600,()=>true),true,'replace target');
assert.equal(s.v86to89.targets.length,1);
assert.equal(api.target(s,'unknown',100,()=>true),false);
assert.equal(api.target(s,'youth-a',79,()=>true),false);
assert.equal(api.minutesReport(s)[0].played,400);
assert.equal(api.minutesReport(s)[0].alert,'retard');
assert.equal(api.succession(s).find(x=>x.pos==='10').successors[0].id,'youth-a');
const options=api.loanOptions(s,'youth-b');
assert.equal(options.length,2);
assert.equal(options[0].to,1,'lower competition leads to more expected minutes');
assert.ok(options[0].expectedMinutes>options[1].expectedMinutes);
assert.equal(api.record(s,'youth-a','formation','Premier XV',()=>true),true);
assert.equal(api.record(s,'youth-a','formation','Rejet',()=>false),false);
assert.equal(api.career(s,'youth-a').events.length,1);
assert.ok(api.career(s,'youth-b').events.some(e=>e.type==='premier-contrat'));
assert.ok(api.panel(s).includes('Objectifs de minutes'));
const legacy=state();assert.equal(api.ensure(legacy).version,1,'legacy save additive');
const saved=JSON.parse(JSON.stringify(s));
assert.equal(api.valid(saved.v86to89),true,'json save roundtrip');
s.season=2;api.ensure(s);
assert.equal(s.v86to89.history.length,1);
assert.equal(s.v86to89.targets.length,0);
assert.equal(api.valid(s.v86to89),true);
console.log('V86-V89 PASS: minutes, alerts, succession, loans, career, save rollback, legacy, season');
