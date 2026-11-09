'use strict';
const assert=require('node:assert/strict'),{test}=require('node:test');
const {context}=require('./france-harness.cjs');

function finance(fixture,world=true){
 const h=context(52602);
 Object.assign(h.ctx,{fixture,world});
 h.run([
  'start(0);S.worldVersion=1;worldSetup();',
  'const CDWorldCareer={active:()=>world};',
  'const ids=fixture.pair, initial=ids.map(id=>S.clubs[id].cash);',
  'worldWeeklyEconomy([fixture]);',
  'const delta=ids.map((id,i)=>S.clubs[id].cash-initial[i]);',
  'const repeat=worldWeeklyEconomy([fixture]);',
  'const final=ids.map((id,i)=>S.clubs[id].cash-initial[i]);'
 ].join('\n'));
 return {delta:Array.from(h.run('delta')),final:Array.from(h.run('final')),repeat:h.run('repeat'),seed:h.seed()};
}
const draw={pair:[1,2],score:[18,18],phase:'league',competitionId:'elite',neutral:false};
const expected=new Map([[1,[80000,0]],[2,[0,80000]]]);

test('Monde : la prime d’un KO départagé au même score va au vrai vainqueur IA une seule fois',()=>{
 const reference=finance(draw);
 for(const winner of [1,2]){
  const record={...draw,phase:'semi',winner};
  const actual=finance(record);
  assert.deepEqual(actual.delta.map((d,i)=>d-reference.delta[i]),expected.get(winner));
  assert.equal(actual.repeat,false);
  assert.deepEqual(actual.final,actual.delta);
  assert.equal(actual.seed,reference.seed);
  assert.deepEqual(finance(record,false),finance(draw,false));
 }
});

test('Monde : une manche nulle du barrage Japon n’anticipe pas le résultat cumulé',()=>{
 const leg={...draw,phase:'promotion',competitionId:'jlo-d1-d2'};
 const reference=finance(leg);
 const actual=finance({...leg,score:[18,24]});
 assert.deepEqual(actual.delta.map((d,i)=>d-reference.delta[i]),[0,80000]);
});
