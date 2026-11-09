'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const directory='../native/engine/';
const legacy=require(directory+'world-registry.json');
const registry=require(directory+'world-pacific-registry.cjs');
const {createWorldEditions}=require(directory+'world-editions.cjs');
const pacific=registry.extendWorldRegistry(legacy,require(directory+'world-pacific-extension.json'));
const japan=registry.extendJapanRegistry(pacific,require(directory+'world-japan-extension.json'));
const id='rugby-world-2026-11-09-nationale-v4',marker={id,version:4};
const moved=japan.clubs[21].players[0],profiles={};
const clubs=Array.from({length:14},(_,i)=>{
 const p='world:fixture-nat:'+i;profiles[p]={scope:'test'};
 return {id:88+i,key:'nat:slot-'+(88+i),leagueId:'nationale',players:[{id:p,worldRatingsVersion:1}]};
});
const delta={id,version:4,marker,baseId:japan.id,snapshot:'2026-11-09',clubs,moves:[[moved.id,21,90]],worldProfiles:profiles};
test('Nationale extends the playable roster without replacing or duplicating a known player',()=>{
 const n=registry.extendNationaleRegistry(japan,delta);
 a.equal(n.clubCount,102);a.equal(n.playerCount,japan.playerCount+14);
 a.equal(n.clubs[90].players.at(-1),moved);a.ok(japan.clubs[21].players.includes(moved));
 a.ok(!n.clubs[21].players.includes(moved));a.equal(n.clubs.flatMap(c=>c.players).filter(p=>p.id===moved.id).length,1);
 a.equal(n.japanCategories,japan.japanCategories);a.equal(n.initialEurope,japan.initialEurope);
 const editions=createWorldEditions(legacy,pacific,japan,n),edition=editions.forMode('world-nationale');
 a.equal(edition.playable.length,100);a.equal(edition.leagueIds.at(-1),'nationale');a.equal(edition.registry,n);
 a.equal(editions.forMode('world-japan').registry,japan);
 a.equal(editions.forState({worldMode:{catalogue:id,version:4},commonDatabase:marker}),edition);
 a.equal(editions.forState({worldMode:{catalogue:id,version:4},commonDatabase:japan.marker}),null);
 a.equal(editions.forState({worldMode:{catalogue:id,version:3},commonDatabase:marker}),null);
});
test('Nationale rejects a wrong edition parent and a hybrid domestic structure',()=>{
 a.throws(()=>registry.extendNationaleRegistry(pacific,delta),/Nationale invalide/);
 a.throws(()=>registry.extendNationaleRegistry(japan,{...delta,clubs:clubs.map((c,i)=>i===0?{...c,leagueId:'accession'}:c)}),/Nationale invalide/);
 const n=registry.extendNationaleRegistry(japan,delta);
 a.throws(()=>createWorldEditions(legacy,pacific,null,n),/Nationale|nationale/);
});