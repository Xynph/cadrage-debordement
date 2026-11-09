'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const base=require('../native/engine/world-registry.json');
const ledger=require('../native/engine/srp-calendar-2027.json');
const {context}=require('./france-harness.cjs');
const {bootstrap}=require('../native/engine/world-vm.cjs');

test('Le Pacifique possède ses 80 rencontres et n’entre jamais dans les poules européennes initiales',()=>{
 // Roster fixture, deliberately not a claim about the SRP database. Clone
 // anonymous foreign profiles with distinct synthetic IDs to exercise saves.
 const id='rugby-world-2026-11-09-pacific-v2',version=2;
 const worldProfiles={...base.worldProfiles};
 const clubs=ledger.clubKeys.map((key,index)=>{
  const sample=base.clubs[30+index];
  const players=sample.players.map((p,i)=>{
   const syntheticId='world:test-pacific:'+index+':'+i;
   worldProfiles[syntheticId]=base.worldProfiles[p.id];
   return {...p,id:syntheticId,name:'Joueur Test '+index+' '+i};
  });
  return {...sample,id:58+index,key,leagueId:'srp',country:'NZ',abbr:'T'+index,name:'Franchise Test '+index,players};
 });
 const registry={...base,id,version,marker:{id,version},clubCount:68,playerCount:base.playerCount+clubs.reduce((n,c)=>n+c.players.length,0),clubs:base.clubs.concat(clubs),leagues:base.leagues.concat({id:'srp',name:'Super Rugby Pacific'}),worldProfiles};
 const h=context();
 h.ctx.nativeWorldRegistryText=JSON.stringify(base);
 h.ctx.nativeWorldPacificRegistryText=JSON.stringify(registry);
 h.run(bootstrap());
 assert.throws(()=>h.run("CDWorldCareer.start(56,'world-pacific')"),/club jouable/);
 h.run("CDWorldCareer.start(58,'world-pacific'); validateCareer(S);");
 const state=JSON.parse(h.run('JSON.stringify(S)'));
 assert.equal(state.club,58);
 assert.deepEqual(state.commonDatabase,{id,version});
 assert.equal(state.clubs.length,68);
 assert.deepEqual(state.worldMode.europe.champions.pools,base.initialEurope.champions);
 assert.deepEqual(state.worldMode.europe.challenge.pools,base.initialEurope.challenge);
 const fixtures=state.worldMode.fixtures.filter(f=>f.competitionId==='srp');
 assert.equal(fixtures.length,80);
 assert.equal(fixtures[0].date,'2027-02-12');
 assert.equal(fixtures[0].week,23);
 for(const c of clubs){
  assert.equal(fixtures.filter(f=>f.homeId===c.id).length,8);
  assert.equal(fixtures.filter(f=>f.awayId===c.id).length,8);
 }
 assert.throws(()=>h.run("const fraud=JSON.parse(JSON.stringify(S));fraud.club=57;CDWorldCareer.validate(fraud);"),/fondation de base invalide/);
 assert.throws(()=>h.run("const fraud2=JSON.parse(JSON.stringify(S));fraud2.worldMode.europe.challenge.pools[0][0]=58;validateCareer(fraud2);"),/poules initiales/);
});
