'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const {createWorldEditions}=require('../native/engine/world-editions.cjs');
const {extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry}=require('../native/engine/world-pacific-registry.cjs');
const staff=require('../native/engine/staff.cjs');

const base=require('../native/engine/world-registry.json');
const pacific=extendWorldRegistry(base,require('../native/engine/world-pacific-extension.json'));
const japan=extendJapanRegistry(pacific,require('../native/engine/world-japan-extension.json'));
const nationale=extendNationaleRegistry(japan,require('../native/engine/world-nationale-extension.json'));
const delta=require('../native/engine/world-champ-extension.json');
const champ=extendChampRegistry(nationale,delta);

test('Champ étend la Nationale et conserve les objets antérieurs par identifiant',()=>{
 assert.equal(champ.clubs.length,116);
 assert.equal(champ.leagues.at(-1).id,'champ');
 assert.equal(champ.playerCount,nationale.playerCount+delta.clubs.flatMap(c=>c.players).length);
 assert.equal(champ.nationaleQualifications,nationale.nationaleQualifications);
 assert.equal(champ.japanCategories,nationale.japanCategories);
 const players=new Map(champ.clubs.flatMap(c=>c.players.map(p=>[p.id,p])));
 assert.equal(players.size,champ.playerCount);
 for(const c of nationale.clubs)for(const p of c.players)assert.equal(players.get(p.id),p);
 assert.throws(()=>extendChampRegistry(japan,delta),/édition de départ/);
 assert.throws(()=>extendChampRegistry(nationale,{...delta,moves:[['faux',0,102]]}),/transfert/);
 const nStaff=staff.forDatabase(nationale.id),cStaff=staff.forDatabase(champ.id);
 assert.equal(cStaff.registry.clubs.length,116);
 for(const id of nStaff.ids)assert.ok(cStaff.ids.has(id));
});

test('Limites et marqueurs d’édition isolés',()=>{
 const editions=createWorldEditions(base,pacific,japan,nationale,champ),MiB=1024*1024;
 assert.deepEqual(editions.entries.map(e=>[e.version,e.clubCount,e.limits.maxMatches,e.limits.saveBytes/MiB,e.limits.requestBytes/MiB]),
  [[1,58,1200,16,34],[2,68,1200,16,34],[3,88,1200,16,34],[4,102,1400,20,42],[5,116,1600,24,50]]);
 const expected=editions.forMode('world-champ');
 assert.equal(expected.playable.length,114);
 assert.deepEqual(expected.guests,[56,57]);
 const state={commonDatabase:champ.marker,worldMode:{catalogue:champ.id,version:5}};
 assert.equal(editions.forState(state),expected);
 assert.equal(editions.forState({...state,commonDatabase:nationale.marker}),null);
 assert.equal(editions.forState({...state,worldMode:{...state.worldMode,version:4}}),null);
 assert.equal(editions.forState({...state,franceMode:{version:1}}),null);
});
