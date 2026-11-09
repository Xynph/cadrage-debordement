'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const base=require('../native/engine/world-registry.json');
const pacificDelta=require('../native/engine/world-pacific-extension.json');
const {extendWorldRegistry,extendJapanRegistry}=require('../native/engine/world-pacific-registry.cjs');
const {createWorldEditions}=require('../native/engine/world-editions.cjs');
const pacific=extendWorldRegistry(base,pacificDelta);
const id='rugby-world-2026-11-09-japan-v3',marker={id,version:3};
const worldProfiles={};
const clubs=Array.from({length:20},(_,i)=>{
 const pid='world:test-jp:'+i;
 worldProfiles[pid]={basis:'test-fixture'};
 return {id:68+i,key:'jlo:test-'+i,leagueId:i<12?'jlo-d1':'jlo-d2',players:[{id:pid,worldRatingsVersion:1}]};
});
const existing=pacific.clubs[60].players[0];
const extension={id,version:3,marker,baseId:pacific.id,snapshot:'2026-11-09',clubs,moves:[[existing.id,60,68]],worldProfiles};

test('Le Japon ajoute 12+8 clubs sans modifier les deux éditions déjà jouables',()=>{
 const j=extendJapanRegistry(pacific,extension);
 assert.equal(j.clubCount,88);
 assert.equal(j.playerCount,pacific.playerCount+20);
 assert.equal(j.clubs[60].players.some(p=>p.id===existing.id),false);
 assert.equal(j.clubs[68].players.at(-1),existing);
 assert.equal(pacific.clubs[60].players[0],existing);
 assert.equal(j.initialEurope,pacific.initialEurope);
 const editions=createWorldEditions(base,pacific,j);
 assert.equal(editions.forMode('world').registry,base);
 assert.equal(editions.forMode('world-pacific').registry,pacific);
 const edition=editions.forMode('world-japan');
 assert.equal(edition.registry,j);
 assert.deepEqual(edition.leagueIds,['elite','accession','prem','urc','srp','jlo-d1','jlo-d2']);
 assert.equal(edition.playable.length,86);
 assert.ok(!edition.playable.includes(56)&&!edition.playable.includes(57));
 const state={worldMode:{catalogue:id,version:3},commonDatabase:marker};
 assert.equal(editions.forState(state),edition);
 assert.equal(editions.forState({...state,commonDatabase:pacific.marker}),null);
});

test('Un faux périmètre japonais ou un marqueur partiellement chargé est refusé',()=>{
 assert.throws(()=>extendJapanRegistry(base,extension),/Extension Japon invalide/);
 assert.throws(()=>extendJapanRegistry(pacific,{...extension,clubs:clubs.slice(1)}),/Extension Japon invalide/);
 assert.throws(()=>extendJapanRegistry(pacific,{...extension,clubs:clubs.map((c,i)=>i===11?{...c,leagueId:'jlo-d2'}:c)}),/Extension Japon invalide/);
 const j=extendJapanRegistry(pacific,extension);
 assert.throws(()=>createWorldEditions(base,null,j),/Configuration d’édition mondiale invalide/);
 const old=createWorldEditions(base,pacific);
 assert.equal(old.forState({worldMode:{catalogue:id,version:3},commonDatabase:marker}),null);
});
