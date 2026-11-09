'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const base=require('../native/engine/world-registry.json');
const {createWorldEditions}=require('../native/engine/world-editions.cjs');

const pacificId='rugby-world-2026-11-09-pacific-v2';
const pacific={
 id:pacificId,version:2,marker:{id:pacificId,version:2},clubCount:68,
 clubs:base.clubs.concat(Array.from({length:10},(_,i)=>({id:58+i,leagueId:'srp'}))),
 leagues:base.leagues.concat({id:'srp',name:'Super Rugby Pacific'}),
};
const state=({marker})=>({commonDatabase:{...marker},worldMode:{catalogue:marker.id,version:marker.version}});

test('Monde ancien et étendu gardent leurs marqueurs et leurs sélections',()=>{
 const disabled=createWorldEditions(base);
 assert.equal(disabled.forMode('world-pacific'),null);
 assert.equal(disabled.forState(state(pacific)),null);
 const router=createWorldEditions(base,pacific);
 const v1=router.forMode('world'),v2=router.forMode('world-pacific');
 assert.equal(router.forState(state(base)),v1);
 assert.equal(router.forState(state(pacific)),v2);
 assert.equal(router.forDatabase(pacificId),v2);
 assert.equal(v1.registry,base);
 assert.equal(v2.registry,pacific);
 assert.deepEqual(v1.leagueIds,['elite','accession','prem','urc']);
 assert.deepEqual(v2.leagueIds,['elite','accession','prem','urc','srp']);
 assert.equal(v1.playable.length,56);
 assert.equal(v2.playable.length,66);
 assert.deepEqual(v2.playable.slice(56),[58,59,60,61,62,63,64,65,66,67]);
 assert.ok(!v2.playable.includes(56)&&!v2.playable.includes(57));
});

test('Un marqueur hybride ou une édition incomplète est refusé',()=>{
 const router=createWorldEditions(base,pacific);
 assert.equal(router.forState({...state(base),worldMode:state(pacific).worldMode}),null);
 assert.equal(router.forState({...state(base),commonDatabase:{...base.marker,extra:true}}),null);
 assert.equal(router.forState({...state(pacific),franceMode:{version:1}}),null);
 assert.equal(router.forState({...state(pacific),lnrMode:{version:1}}),null);
 assert.equal(router.forState({commonDatabase:pacific.marker,worldMode:{catalogue:pacificId,version:1}}),null);
 assert.throws(()=>createWorldEditions(base,{...pacific,clubs:pacific.clubs.slice(1)}),/édition mondiale/);
 const forged={...pacific,clubs:pacific.clubs.map(c=>c.id===57?{...c,leagueId:'srp'}:c)};
 assert.throws(()=>createWorldEditions(base,forged),/édition mondiale/);
});
