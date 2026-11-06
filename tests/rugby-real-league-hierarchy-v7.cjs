'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {run,ROLE}=require('../tools/rugby-real-league-hierarchy-v7.cjs');
const keys=[...new Set(Object.values(ROLE).flat())];
function fixture(opts={}){
 const positions=Object.keys(ROLE);
 const players=Array.from({length:1592},(_,i)=>{
   const league=i<805?'top14':'prod2',role=positions[i%positions.length];
   const base=league==='top14'?(opts.topBaseline??65):(opts.proBaseline??65);
   const a=Object.fromEntries(Array.from({length:36-keys.length},(_,j)=>['other'+j,base]));
   for(const key of keys)a[key]=Math.max(20,Math.min(97,base+(i%5)-2));
   return {id:'stable-'+i,league,gameplayPosition:role,attributesV2:a,potential:85};
 });
 return {players};
}
test('coverage 1592, determinism, no mutation',()=>{
 const master=fixture(),old=JSON.stringify(master);
 const a=run(master),b=run(master);
 assert.equal(a.candidates.length,1592);assert.deepEqual(a,b);assert.equal(JSON.stringify(master),old);
});
test('league prior increases TOP14 role means if necessary',()=>{
 const r=run(fixture());
 for(const x of Object.values(r.roleReports)){
  assert.ok(x.gapAfter>=x.gapBefore);
  assert.ok(x.top14MeanAfter>=x.top14MeanBefore);
  assert.ok(x.gapAfter>=2.5);
 }
});
test('strong existing league gap is preserved untouched',()=>{
 const r=run(fixture({topBaseline:77,proBaseline:63}));
 assert.equal(r.affectedPlayers,0);
 assert.ok(Object.values(r.roleReports).every(x=>x.suggestedTop14Bonus===0));
});
test('no PRO D2 downgrade, no per-player rank forcing',()=>{
 const r=run(fixture());
 assert.ok(r.candidates.filter(p=>p.league==='prod2').every(p=>p.changes.length===0));
 assert.ok(r.candidates.every(p=>p.changes.every(x=>x.delta>0&&x.delta<=3&&x.to<=97&&x.kind==='model-estimate')));
});
test('invalid player IDs fail closed',()=>{
 const d=fixture();d.players[1].id=d.players[0].id;
 assert.throws(()=>run(d),/Duplicate\/missing/);
});
