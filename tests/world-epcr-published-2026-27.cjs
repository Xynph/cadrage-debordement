'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const R=require('../native/engine/world-registry.json');
const venue=require('../native/engine/world-venues.cjs');
test('Les finales EPCR de la seule édition publiée affichent le terrain neutre lyonnais',()=>{
 for(const [competitionId,date] of [['champions','2027-05-22'],['challenge','2027-05-21']]){
  const match=Object.freeze({competitionId,date,phase:'final',neutral:true});
  a.equal(venue(match,1),'OL Stadium · Lyon');
  a.equal(venue(match,2),null);
  a.equal(venue({...match,neutral:false},1),null);
  a.equal(venue({...match,date:'2027-05-23'},1),null);
 }
 a.equal(venue({competitionId:'elite',date:'2027-05-22',phase:'final',neutral:true},1),null);
});
test('Le tirage Challenge publié respecte les contraintes spécifiques 2026–27',()=>{
 const pools=R.initialEurope.challenge.map(ids=>ids.map(id=>R.clubs[id]));
 const south=new Set(['urc:sharks','guest:cheetahs','guest:black-lion']);
 a.equal(pools.length,3);
 for(const pool of pools){
  a.equal(pool.length,6);
  a.equal(pool.filter(c=>c.leagueId==='elite').length,2);
  a.equal(pool.filter(c=>c.shield==='wales').length,1);
  a.ok(pool.filter(c=>c.leagueId==='urc').length<=3);
  a.ok(pool.filter(c=>c.leagueId==='prem').length<=1);
  a.equal(pool.filter(c=>c.shield==='scotland-italy').length,1);
  a.equal(pool.filter(c=>south.has(c.key)).length,1);
 }
});

test('Les 84 rencontres de poules reprennent le stade publié ou la mention à confirmer',()=>{
 const evidence=require('../native/engine/epcr-pool-venues-2026-27.json');
 const official=[...R.initialFixtures.champions,...R.initialFixtures.challenge];
 a.equal(official.length,84);
 a.equal(Object.keys(evidence.venues).length,84);
 a.equal(Object.values(evidence.venues).filter(f=>f.venue===null).length,1);
 for(const fixture of official){
  const row=evidence.venues[fixture.id];
  a.ok(row,fixture.id);
  a.deepEqual([row.sourceFixtureId,row.date,row.homeId,row.awayId],
   [fixture.sourceFixtureId,fixture.date,fixture.homeId,fixture.awayId]);
  a.equal(venue(fixture,1),row.venue??'Stade à confirmer');
  a.equal(venue(fixture,2),null);
  a.equal(venue({...fixture,sourceFixtureId:fixture.sourceFixtureId+1},1),null);
  a.equal(venue({...fixture,date:'2027-01-01'},1),null);
 }
 const awayFromHome=official.filter(f=>f.homeId===56);
 a.equal(awayFromHome.length,2);
 a.ok(awayFromHome.every(f=>venue(f,1)==="St Helen's"));
});
