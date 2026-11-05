'use strict';
const assert=require('node:assert/strict');
globalThis.CDEspoirsPathwaysV78V81={ensure:s=>s.v78to81||null};
const api=require('../dist/espoirs-career-v82-v85.js');
function state(){
 const y=(id,pos)=>({id,name:id,age:19,pos,rating:60,condition:85,dev:{potential:75}});
 const p=(id,pos)=>({id,name:id,age:29,pos,rating:81,condition:88,dev:{potential:85}});
 return {season:1,club:0,phase:'league',live:false,news:[],ledger:[],
  clubs:[{name:'Club 0',cash:200000,players:[p('senior1','10'),p('senior2','9')]},
   {name:'Accueil',players:[{...y('loan','10'),dev:{potential:75,minutes:350}}]}],
  development:{academy:[y('young1','10'),y('young2','9'),y('young3','10')]},
  v78to81:{version:1,season:1,loans:[{id:'loan',name:'loan',to:1}],history:[]},
  v73Espoirs:{minutes:{young1:600,young2:700,young3:350}},
  v77Promotions:{promotions:[{playerId:'x',season:1},{playerId:'z',season:1}]}
 };
}
const s=state();
assert.equal(api.ensure(s).version,1);
assert.equal(api.valid(s.v82to85),true);
assert.equal(api.plan(s,'young1','minutes',()=>false),false,'failed save must undo plan');
assert.equal(s.v82to85.plans.length,0);
assert.equal(api.plan(s,'young1','minutes',()=>true),true);
assert.equal(api.plan(s,'young2','regularite',()=>true),true);
assert.equal(api.plan(s,'young1','minutes',()=>true),false,'no duplicate');
assert.equal(api.mentor(s,'young1','senior1',()=>true),true);
assert.equal(api.mentor(s,'young2','senior2',()=>true),true);
assert.equal(api.mentor(s,'young2','senior1',()=>true),false,'no repeated mentor');
assert.equal(api.goal(s,'formation',()=>true),true);
assert.equal(api.report(s)[0].minutes,350);
const before=JSON.stringify(s);
s.phase='ended';
const preRollback=JSON.stringify(s);
assert.equal(api.seasonEnd(s,()=>false),false,'annual save failure rolls back');
assert.equal(JSON.stringify(s),preRollback,'annual progression and cash fully rolled back');
assert.equal(api.seasonEnd(s,()=>true),true);
assert.equal(api.seasonEnd(s,()=>true),false,'idempotent once per season');
assert.equal(s.v82to85.history[0].completed,true);
assert.equal(s.v82to85.history[0].reward,24000);
assert.equal(s.clubs[0].cash,224000);
assert.equal(s.v82to85.history[0].mentorshipBonuses,2);
assert.equal(s.v82to85.reports[0].successful,true);
assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v82to85),true,'native JSON');
assert.ok(api.panel(s).includes('V82–V85'));
for(let year=2;year<=8;year++){
 s.season=year;s.phase='league';s.v78to81.season=year;api.ensure(s);
 assert.equal(s.v82to85.plans.length,0);
 assert.equal(api.valid(s.v82to85),true);
 s.phase='ended';assert.equal(api.seasonEnd(s,()=>true),true);
}
assert.equal(s.v82to85.history.length,4,'history bounded');
assert.equal(api.valid(s.v82to85),true);
const legacy=state();delete legacy.v82to85;
assert.ok(api.ensure(legacy),'old saves accepted without migration');
const missing=state();delete missing.news;delete missing.ledger;
assert.equal(api.plan(missing,'young1','minutes',()=>true),true,'no news');
missing.phase='ended';assert.equal(api.seasonEnd(missing,()=>true),true,'no ledger');
const corrupt=state();corrupt.v82to85={version:42};
assert.equal(api.ensure(corrupt),null,'corrupt state rejected');
console.log('V82-V85 PASS: goals, mentoring, loan report, native save rollback, old saves, eight seasons, UI');
