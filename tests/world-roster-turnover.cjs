'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const {inventory,reconcile,argumentsFor}=require('../ci/world-roster-turnover-audit.cjs');
const p=(id,contractEnd=1)=>({id,age:24,salary:2000,contractEnd});
function state(clubs,academy=[],market=[],retired=[]){return {season:1,round:46,club:0,clubs:clubs.map((players,id)=>({id,players})),development:{academy,retired},market,economy:{freeAgents:market},aiRoster:{academies:[]}};}
test('Transfers, promotions, releases and known retirements reconcile ID conservation',()=>{
 const before=state([[p('stays'),p('moves'),p('released'),p('retires'),p('lost')],[]],[p('youth')]);
 const after=state([[p('stays'),p('youth')],[p('moves'),p('emergency')] ],[],[p('released')],[{id:'retires',season:1}]);
 const r=reconcile(inventory(before),inventory(after),[{season:2,clubId:1,kind:'emergency',playerId:'emergency',fee:0}]);
 a.deepEqual(Object.fromEntries(r.flows.map(f=>[f.id,f.kind])),{moves:'recruitment',released:'release',retires:'retirement',lost:'unknown',youth:'promotion',emergency:'emergency'});
 a.equal(r.unknown,1);a.ok(r.conservation.every(c=>c.residual===0));a.deepEqual(r.conservation.find(c=>c.clubId===0),{clubId:0,before:5,arrivals:1,departures:4,after:2,residual:0});
});
test('No retirement invented for a disappearance; market refresh stays a surface change',()=>{
 const before=inventory(state([[p('vanishes')]],[],[p('market-only')]));const after=inventory(state([[]]));const r=reconcile(before,after);
 a.equal(r.flows.find(f=>f.id==='vanishes').kind,'unknown');a.equal(r.flows.find(f=>f.id==='market-only').kind,'pool-change');
 a.equal(reconcile(before,inventory(state([[]],[],[],[{id:'market-only',season:1}]))).flows.find(f=>f.id==='market-only').kind,'retirement');
});
test('Market/free-agent aliases deduplicate; duplicate professional ownership is refused',()=>{
 const row=inventory(state([[p('own')]],[],[p('market')]));a.equal(row.counts.unique,2);a.deepEqual(row.players.market.locations,['market','free-agents']);a.throws(()=>inventory(state([[p('duplicate')],[p('duplicate')]])),/duplicate professional owner/);
});
test('Same-club duplicate professionals cannot produce a false zero-residual balance',()=>{
 const malformed=state([[p('same-id'),p('same-id')]]);
 a.throws(()=>inventory(malformed),/duplicate professional/);
 a.throws(()=>reconcile(inventory(malformed),inventory(malformed)),/duplicate professional/);
});
test('Analysis preserves all input objects, including event evidence',()=>{
 const before=state([[p('release')]]),after=state([[]],[],[p('release')]),events=[{season:1,clubId:0,kind:'release',playerId:'release',fee:0}],copy=JSON.stringify({before,after,events});
 reconcile(inventory(before),inventory(after),events);a.equal(JSON.stringify({before,after,events}),copy);
});
test('CLI demands explicit bounded experiment and output destination',()=>{
 a.equal(argumentsFor(['--seed','827381','--mode','world-champ','--out','/tmp/cd-turnover-not-created.json']).mode,'world-champ');a.throws(()=>argumentsFor(['--out','/tmp/cd-turnover-not-created.json']),/seed/);a.throws(()=>argumentsFor(['--seed','1','--seasons','10','--out','/tmp/cd-turnover-not-created.json']),/one or two/);
});
