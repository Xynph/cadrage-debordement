'use strict';
// Super Rugby Pacific dans la carrière Monde (world-champ) : 80 rencontres réelles du calendrier 2027,
// jamais dans les poules européennes initiales.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const base=require('../native/engine/world-registry.json');
const ledger=require('../native/engine/srp-calendar-2027.json');
const {context}=require('./monde-harness.cjs');

test('Le Pacifique possède ses 80 rencontres et n’entre jamais dans les poules européennes initiales',()=>{
 const h=context(827381,{club:58});
 try{
  const state=JSON.parse(h.run('JSON.stringify(S)'));
  const srp=state.worldMode.leagues.srp.members;
  assert.equal(state.club,58);assert.ok(srp.includes(58));assert.equal(srp.length,ledger.clubKeys.length);
  assert.deepEqual(state.commonDatabase,{id:'rugby-world-2026-11-09-champ-v5',version:5});
  assert.equal(state.clubs.length,116);
  assert.deepEqual(state.worldMode.europe.champions.pools,base.initialEurope.champions);
  assert.deepEqual(state.worldMode.europe.challenge.pools,base.initialEurope.challenge);
  const fixtures=state.worldMode.fixtures.filter(f=>f.competitionId==='srp');
  assert.equal(fixtures.length,80);
  assert.equal(fixtures[0].date,'2027-02-12');
  assert.equal(fixtures[0].week,25,'semaine de gestion du Monde complet (saison ouverte plus tôt)');
  for(const id of srp){
   assert.equal(fixtures.filter(f=>f.homeId===id).length,8);
   assert.equal(fixtures.filter(f=>f.awayId===id).length,8);
  }
  // Un club non jouable de l'édition est refusé à la création et dans une sauvegarde.
  const unplayable=h.run('JSON.stringify(S.clubs.map(c=>c.id).filter(id=>!CDWorldEditions.forState(S).playable.includes(id)))');
  const refused=JSON.parse(unplayable)[0];assert.ok(Number.isInteger(refused),'au moins un club non jouable');
  assert.throws(()=>h.command('new_career',{mode:'world-champ',club:refused}),/Club invalide/);
  assert.equal(h.run('S.club'),58,'refus sans perte de la carrière');
  assert.throws(()=>h.run('const fraud=JSON.parse(JSON.stringify(S));fraud.club='+refused+';CDWorldCareer.validate(fraud);'),/fondation de base invalide/);
  assert.throws(()=>h.run("const fraud2=JSON.parse(JSON.stringify(S));fraud2.worldMode.europe.challenge.pools[0][0]=58;validateCareer(fraud2);"),/poules initiales/);
 }finally{h.close();}
});
