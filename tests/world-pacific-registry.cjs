'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const base=require('../native/engine/world-registry.json');
const {extendWorldRegistry}=require('../native/engine/world-pacific-registry.cjs');
const keys=require('../native/engine/srp-calendar-2027.json').clubKeys;
const id='rugby-world-2026-11-09-pacific-v2';
const moved=base.clubs[32].players[0];
const worldProfiles={};
const clubs=keys.map((key,i)=>{
 const pid='world:pacific-fixture:'+i;
 worldProfiles[pid]={basis:'test-fixture'};
 return {id:58+i,key,leagueId:'srp',players:[{id:pid,worldRatingsVersion:1}]};
});
const extension={id,version:2,marker:{id,version:2},snapshot:'2026-11-09',baseId:base.id,clubs,worldProfiles,moves:[[moved.id,32,58]]};

test('Un transfert Pacifique garde un seul joueur et préserve les deux bases sources',()=>{
 const v2=extendWorldRegistry(base,extension);
 assert.equal(v2.clubCount,68);
 assert.equal(v2.playerCount,base.playerCount+10);
 assert.equal(v2.clubs[32].players.some(p=>p.id===moved.id),false);
 assert.equal(v2.clubs[58].players.at(-1),moved);
 assert.equal(v2.clubs.flatMap(c=>c.players).filter(p=>p.id===moved.id).length,1);
 assert.equal(base.clubs[32].players[0],moved);
 assert.equal(extension.clubs[0].players.length,1);
 assert.equal(v2.initialEurope,base.initialEurope);
});

test('Le raccord refuse un joueur dupliqué ou un transfert incohérent',()=>{
 assert.throws(()=>extendWorldRegistry(base,{...extension,moves:[[moved.id,33,58]]}),/transfert non unique/);
 assert.throws(()=>extendWorldRegistry(base,{...extension,moves:[[moved.id,32,58],[moved.id,32,59]]}),/transfert non unique/);
 const duplicate=clubs.map((c,i)=>i===0?{...c,players:[{...moved,worldRatingsVersion:1}]}:c);
 assert.throws(()=>extendWorldRegistry(base,{...extension,clubs:duplicate}),/profil Pacifique dupliqué/);
});
