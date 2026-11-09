'use strict';
const assert=require('node:assert/strict'),{test}=require('node:test');
const C=require('../native/engine/world-competitions.cjs').factory();
const R=require('../native/engine/world-registry.json');
const base=R.initialEurope.challenge.flat();
const nonURC=base.filter(id=>R.clubs[id].leagueId!=='urc');
const args=(urc=[40,41,42,43,46,47,48,49])=>{
 const participants=[...nonURC,...urc];
 const order=Array(18);
 for(const [i,id] of urc.entries())order[[0,3,6,9,1,4,7,10][i]]=id;
 const other=nonURC.slice();
 for(let i=0;i<order.length;i++)if(order[i]===undefined)order[i]=other.shift();
 return {competitionId:'challenge',clubs:R.clubs,participants,order};
};
const league=id=>R.clubs[id].leagueId;
const policy='balanced-challenge-v1';
function balanced(f){return C.drawPools({...f,challengeDrawPolicy:policy});}

test('le tirage sans politique reste exactement celui des sauvegardes historiques',()=>{
 const f=args();
 assert.deepEqual(C.drawPools(f),[0,1,2].map(p=>f.order.filter((_,i)=>i%3===p)));
});
test('la politique future équilibre les poules et produit quatre vrais matchs par club',()=>{
 const f=args(),pools=balanced(f);
 assert.notDeepEqual(pools,C.drawPools(f));
 assert.deepEqual(balanced(f),pools);
 assert.equal(new Set(pools.flat()).size,18);
 const urcCounts=[],matchedShields=[];
 for(const pool of pools){
  assert.equal(pool.length,6);
  assert.equal(pool.filter(id=>league(id)==='elite').length,2);
  assert.ok(pool.filter(id=>league(id)==='prem').length<=1);
  assert.ok(pool.filter(id=>league(id)==='guest').length<=1);
  const urc=pool.filter(id=>league(id)==='urc');
  urcCounts.push(urc.length);
  matchedShields.push(urc.length-new Set(urc.map(id=>R.clubs[id].shield)).size);
 }
 assert.deepEqual(urcCounts.sort(),[2,3,3]);
 assert.equal(matchedShields.reduce((a,b)=>a+b,0),2,'quatre par bouclier imposent deux répétitions');
 const schedule=C.poolStage({competitionId:'challenge',clubs:R.clubs,pools,season:2027});
 assert.equal(schedule.length,36);
 for(const id of f.participants){
  assert.equal(schedule.filter(m=>m.homeId===id).length,2);
  assert.equal(schedule.filter(m=>m.awayId===id).length,2);
 }
});
test('une politique inconnue ou un quota impossible est refusé explicitement',()=>{
 const f=args();
 assert.throws(()=>C.drawPools({...f,challengeDrawPolicy:'official-2027'}),/unknown Challenge draw policy/);
 const entrant=f.participants.find(id=>league(id)==='guest');
 const outsider=R.clubs.find(c=>c.leagueId==='elite'&&!f.participants.includes(c.id)).id;
 for(const key of ['participants','order'])f[key]=f[key].map(id=>id===entrant?outsider:id);
 assert.throws(()=>balanced(f),/balanced Challenge requires/);
});
